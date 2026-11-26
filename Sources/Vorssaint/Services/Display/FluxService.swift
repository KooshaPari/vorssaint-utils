// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if canImport(AppKit)
import AppKit
import CoreGraphics
import os

/// Warm-colour schedule for every display: the f.lux job done inside the app
/// that already owns the display pipeline.
///
/// Native rather than a sidecar because the dangerous half of the work is
/// already here. `BrightnessService` captures each display's untouched gamma
/// curve, tags it to the physical monitor's fingerprint, and puts it back on
/// disable, on a display change and on quit. A second gamma writer beside it
/// (f.lux, or a bundled helper) would fight that pipeline for the same tables
/// and whichever wrote last would win the restore. What is genuinely new here
/// is only the schedule and a per-channel gain, both pure and tested in
/// `FluxSupport`; the curve handling is the one this app already trusts.
///
/// Guarantees, all of them exercised by the checks through `FluxSupport`:
/// - a display is only ever written from a curve captured while it was neutral;
/// - restore writes that exact curve back, never a recomputed one;
/// - disabling, sunrise, a manual "off", display changes and quitting all
///   converge on `FluxSupport.actions` asking for `.restore`;
/// - the tint lives in the display server, so it dies with the process even
///   after a crash, and the quit path restores synchronously first anyway.
///
/// The screen observer and the minute tick exist only while the feature is on.
final class FluxService {
    static let shared = FluxService()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "flux")

    /// One display's untouched curve, with the physical monitor it came from.
    /// A display number is handed out again after a reconnection, so a curve is
    /// only ever written back to the monitor whose fingerprint it carries.
    private struct Baseline {
        var red: [CGGammaValue]
        var green: [CGGammaValue]
        var blue: [CGGammaValue]
        var count: UInt32
        var fingerprint: String
    }

    /// The warmth a manual choice is holding, if any. Overrides the schedule
    /// until it is cleared.
    private var overrideKelvin: Double?
    private var baselines: [CGDirectDisplayID: Baseline] = [:]
    private var tinted: Set<CGDirectDisplayID> = []
    private var running = false
    private var timer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var wakeObservers: [NSObjectProtocol] = []
    /// Gamma reads and writes are serialised: a display server that is asked
    /// for a table while another write is landing answers the old one.
    private let workQueue = DispatchQueue(label: "com.vorssaint.utils.flux", qos: .utility)

    private init() {}

    // MARK: - Lifecycle

    /// Starts, stops or re-evaluates from the saved preferences. Called when
    /// display control's settings change and at launch.
    func syncWithPreferences() {
        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.fluxEnabled)
        if enabled {
            start()
            applyNow()
        } else {
            stop(restoring: true)
        }
    }

    /// A manual warmth choice for a future control surface. Passing nil returns
    /// the schedule's own answer.
    func setOverride(kelvin: Double?) {
        workQueue.async { [weak self] in
            guard let self else { return }
            // The override is read by `currentState` on this queue, so it is
            // written here too rather than from the caller's thread.
            self.overrideKelvin = kelvin
            self.evaluateAndApply()
        }
    }

    func start() {
        guard !running else { return }
        running = true
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.displaysChanged()
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            wakeObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                self?.applyNow()
            })
        }
        // The schedule moves continuously; one coarse tick is enough to keep
        // the ramp smooth without a standing high-resolution timer. Tolerance
        // lets the system coalesce it with other wakeups.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.applyNow()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops the observers and, unless a quit path already restored, puts every
    /// ticked display back. Main thread only.
    func stop(restoring: Bool) {
        timer?.invalidate()
        timer = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in wakeObservers { workspace.removeObserver(observer) }
        wakeObservers = []
        running = false
        if restoring { restoreAllSynchronously() }
    }

    /// The quit path. Synchronous on purpose: `applicationWillTerminate` has to
    /// have the curves back on the displays before the process goes away.
    func restoreBeforeTermination() {
        stop(restoring: true)
    }

    // MARK: - Evaluation

    /// The current target for the current minute, in one pure call.
    private func currentState(now: Date = Date()) -> FluxSupport.State {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: DefaultsKey.fluxEnabled)
        let schedule = FluxSupport.Schedule(
            startMinute: defaults.integer(forKey: DefaultsKey.fluxSunsetMinute),
            endMinute: defaults.integer(forKey: DefaultsKey.fluxSunriseMinute),
            transitionMinutes: defaults.integer(forKey: DefaultsKey.fluxTransitionMinutes),
            nightKelvin: defaults.double(forKey: DefaultsKey.fluxNightKelvin),
            mode: FluxSupport.Mode(rawValue: defaults.string(forKey: DefaultsKey.fluxMode) ?? "")
                ?? .fixed)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minute = FluxSupport.minuteOfDay(hour: components.hour ?? 0,
                                             minute: components.minute ?? 0)
        return FluxSupport.state(minuteOfDay: minute, schedule: schedule,
                                 enabled: enabled, overrideKelvin: overrideKelvin)
    }

    /// Recomputes the target and asks the displays to follow it. Cheap and
    /// idempotent: a tick that lands on the same temperature rewrites only what
    /// is not already tinted.
    func applyNow() {
        guard running else { return }
        workQueue.async { [weak self] in
            guard let self else { return }
            self.evaluateAndApply()
        }
    }

    /// Everything that reads or writes the tinted set, the captured curves and
    /// the manual override stays on the work queue, so a tick, an override and
    /// a display change can never interleave their writes.
    private func evaluateAndApply() {
        let state = currentState()
        let plan = FluxSupport.actions(displays: Self.activeDisplays(),
                                       tinted: tinted,
                                       enabled: state.phase != .off,
                                       kelvin: state.kelvin)
        reconcile(plan, kelvin: state.kelvin)
    }

    private func reconcile(_ plan: [(id: UInt32, action: FluxSupport.DisplayAction)],
                           kelvin: Double) {
        for entry in plan {
            switch entry.action {
            case .apply:
                apply(to: entry.id, kelvin: kelvin)
            case .restore:
                restore(entry.id)
            case .none:
                continue
            }
        }
    }

    // MARK: - Displays (work queue)

    private static func activeDisplays() -> [FluxSupport.Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map {
            FluxSupport.Display(id: $0, fingerprint: fingerprint($0))
        }
    }

    /// Identifies the physical monitor behind a display number the same way
    /// `BrightnessService` does, so both writers agree on identity.
    private static func fingerprint(_ id: CGDirectDisplayID) -> String {
        "\(CGDisplayVendorNumber(id)):\(CGDisplayModelNumber(id)):\(CGDisplaySerialNumber(id))"
    }

    /// A display change can add, remove or reassign a number. Anything this app
    /// tinted is restored first, then everything that is no longer present is
    /// forgotten, then the new topology gets the current target. Restoring
    /// first is what keeps a display that was unplugged while warm from coming
    /// back warm under somebody else's curve.
    private func displaysChanged() {
        guard running else { return }
        workQueue.async { [weak self] in
            guard let self else { return }
            for id in FluxSupport.tintsToRestore(self.tinted) { self.restore(id) }
            let live = Set(Self.activeDisplays().map(\.id))
            self.baselines = self.baselines.filter { live.contains($0.key) }
        }
        applyNow()
    }

    /// Captures the display's own curve, once, while it is still showing it.
    private func captureBaseline(_ id: CGDirectDisplayID) -> Baseline? {
        let fingerprint = Self.fingerprint(id)
        if let existing = baselines[id], existing.fingerprint == fingerprint {
            return existing
        }
        let capacity = 256
        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = [CGGammaValue](repeating: 0, count: capacity)
        var blue = [CGGammaValue](repeating: 0, count: capacity)
        var samples: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, UInt32(capacity), &red, &green, &blue,
                                          &samples) == .success, samples > 0 else {
            Self.log.error("cannot read the gamma curve for display \(id)")
            return nil
        }
        let count = Int(min(samples, UInt32(capacity)))
        let baseline = Baseline(red: Array(red.prefix(count)),
                                green: Array(green.prefix(count)),
                                blue: Array(blue.prefix(count)),
                                count: UInt32(count),
                                fingerprint: fingerprint)
        baselines[id] = baseline
        return baseline
    }

    private func apply(to id: CGDirectDisplayID, kelvin: Double) {
        // An exact neutral target restores instead of writing a table scaled by
        // one: the restore is the guarantee, and skipping the write keeps the
        // display server out of a no-op.
        guard FluxSupport.isWarm(kelvin) else {
            restore(id)
            return
        }
        // A curve is only captured while the display is neutral. While this app
        // is tinting it, the live table is our tinted copy, so reading it back
        // would take the tint as the new normal and stack warmth forever.
        guard let baseline = captureBaseline(id) else { return }
        let gains = FluxSupport.gains(forKelvin: kelvin)
        let red = FluxSupport.tintedTable(baseline.red, gain: gains.red)
        let green = FluxSupport.tintedTable(baseline.green, gain: gains.green)
        let blue = FluxSupport.tintedTable(baseline.blue, gain: gains.blue)
        if CGSetDisplayTransferByTable(id, baseline.count, red, green, blue) == .success {
            tinted.insert(id)
            Self.log.debug("display \(id) tinted to \(Int(kelvin.rounded())) K")
        }
    }

    /// Puts the captured curve back exactly. A display number that now belongs
    /// to another monitor is left alone: writing the old monitor's curve to a
    /// stranger would tint or dim a screen this app never changed. Once the
    /// curve is back the baseline is forgotten, so a colour profile the user
    /// changes during the day is read fresh the next evening instead of being
    /// overwritten by last night's table.
    @discardableResult
    private func restore(_ id: CGDirectDisplayID) -> Bool {
        guard let baseline = baselines[id],
              baseline.fingerprint == Self.fingerprint(id) else {
            // Nothing of ours can be live on this number any more.
            tinted.remove(id)
            baselines.removeValue(forKey: id)
            return true
        }
        guard CGSetDisplayTransferByTable(id, baseline.count, baseline.red,
                                          baseline.green, baseline.blue) == .success else {
            Self.log.error("cannot restore the gamma curve for display \(id)")
            return false
        }
        tinted.remove(id)
        baselines.removeValue(forKey: id)
        Self.log.debug("display \(id) restored to its own curve")
        return true
    }

    private func restoreAllSynchronously() {
        workQueue.sync {
            for id in FluxSupport.tintsToRestore(tinted) { restore(id) }
            // A display that is mid-mode-change can refuse the first write; one
            // immediate retry is enough, and the process exit reverts whatever
            // is left anyway.
            for id in FluxSupport.tintsToRestore(tinted) { restore(id) }
            baselines = [:]
        }
    }
}
#endif
