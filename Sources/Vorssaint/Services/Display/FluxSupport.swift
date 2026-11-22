// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The schedule and colour maths behind the display colour temperature
/// feature: when warmth starts and ends, how warm the night target is, how the
/// ramp between them is shaped, and what a display that is already tinted
/// should do next.
///
/// Everything here is pure. There is no AppKit, no CoreGraphics, no clock and
/// no settings read: every value is a parameter. The Windows check harness
/// slices this entire type into `build/generated-tests/` and compiles it beside
/// the tests, so it must never reach for instance state or a macOS-only API.
///
/// Colour accuracy note: warmth is applied as a per-channel gain on the
/// display's own gamma table, never as a replacement curve. The display's
/// captured profile keeps its shape and contrast; only the relative channel
/// energy moves, which is what a colour temperature is.
enum FluxSupport {
    /// Unwarmed daylight. The ramp starts and ends here.
    static let neutralKelvin: Double = 6500
    /// The warmest target the feature will write. Below this the blue channel
    /// is close to gone and the picture reads as orange rather than warm
    /// white, so the floor is deliberate.
    static let minimumKelvin: Double = 1900
    static let maximumKelvin: Double = 6500
    static let minutesPerDay = 1440

    /// How the window is named in the interface. Both variants evaluate from
    /// minute numbers: `fixed` uses the times a person typed, and
    /// `sunsetToSunrise` uses the times a solar calculation supplied for the
    /// current day. The evaluation below is identical either way, which is why
    /// a schedule that crosses midnight needs no special case.
    enum Mode: String, Equatable {
        case fixed
        case sunsetToSunrise
    }

    /// A daily warmth window in minutes after local midnight.
    struct Schedule: Equatable {
        /// When warmth begins: sunset, or the chosen start time.
        var startMinute: Int
        /// When the picture is fully neutral again: sunrise, or the chosen end.
        var endMinute: Int
        /// How long the ramp takes at each end of the window. Zero is a step.
        var transitionMinutes: Int
        /// The colour temperature held through the middle of the window.
        var nightKelvin: Double
        var mode: Mode

        init(startMinute: Int, endMinute: Int, transitionMinutes: Int,
             nightKelvin: Double, mode: Mode = .fixed) {
            self.startMinute = startMinute
            self.endMinute = endMinute
            self.transitionMinutes = transitionMinutes
            self.nightKelvin = nightKelvin
            self.mode = mode
        }
    }

    /// Where in the day's cycle an evaluation landed, so the interface and the
    /// log can say why a display is warm.
    enum Phase: Equatable {
        /// The feature is switched off; everything stays neutral.
        case off
        /// Outside the window, or exactly at its edges.
        case day
        /// Ramping from neutral toward the night target.
        case warming
        /// Holding the night target.
        case night
        /// Ramping from the night target back to neutral.
        case cooling
        /// A manual choice is in force.
        case override
        /// The schedule cannot be evaluated (empty, equal edges, negative or
        /// overlapping ramp), so the display stays neutral rather than guessing.
        case invalid
    }

    struct State: Equatable {
        var kelvin: Double
        var phase: Phase
    }

    // MARK: - Clock helpers

    /// A wall-clock time folded into one day, so a schedule is arithmetic
    /// rather than calendar work. Negative or oversized input wraps.
    static func minuteOfDay(hour: Int, minute: Int) -> Int {
        let total = hour * 60 + minute
        return ((total % minutesPerDay) + minutesPerDay) % minutesPerDay
    }

    /// Minutes after midnight as an offset from an arbitrary origin, wrapped
    /// into one day. Used for both elapsed and window length.
    static func wrapped(_ minutes: Int) -> Int {
        ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
    }

    // MARK: - Validity

    /// A schedule that cannot produce a sane answer stays neutral. Equal edges
    /// have no window, a negative ramp has no direction, and a ramp longer than
    /// half the window would overlap itself, which used to make the middle of a
    /// short winter window flicker between warming and cooling.
    static func isValid(_ schedule: Schedule) -> Bool {
        guard schedule.nightKelvin.isFinite else { return false }
        let cycle = wrapped(schedule.endMinute - schedule.startMinute)
        guard cycle > 0, schedule.transitionMinutes >= 0 else { return false }
        return schedule.transitionMinutes * 2 <= cycle
    }

    /// The ramp length actually used: half the window at most, so a window
    /// shorter than twice the requested ramp still has a flat night middle.
    static func effectiveTransition(_ schedule: Schedule) -> Int {
        let cycle = wrapped(schedule.endMinute - schedule.startMinute)
        return min(max(schedule.transitionMinutes, 0), cycle / 2)
    }

    /// The night target clamped to the range a display can be given without
    /// losing a channel.
    static func clampedKelvin(_ kelvin: Double) -> Double {
        guard kelvin.isFinite else { return neutralKelvin }
        return min(max(kelvin, minimumKelvin), maximumKelvin)
    }

    /// Whether a temperature is warm enough to write. Half a kelvin is well
    /// below anything a person can see, so the boundary is stable.
    static func isWarm(_ kelvin: Double) -> Bool {
        kelvin.isFinite && kelvin < neutralKelvin - 0.5
    }

    // MARK: - Evaluation

    /// The whole decision in one place, in precedence order: disabled wins over
    /// everything, a manual override wins over the schedule, and an unusable
    /// schedule gives up to neutral instead of guessing.
    static func state(minuteOfDay minute: Int,
                      schedule: Schedule?,
                      enabled: Bool,
                      overrideKelvin: Double?) -> State {
        guard enabled else { return State(kelvin: neutralKelvin, phase: .off) }
        if let overrideKelvin, overrideKelvin.isFinite {
            return State(kelvin: clampedKelvin(overrideKelvin), phase: .override)
        }
        guard let schedule, isValid(schedule) else {
            return State(kelvin: neutralKelvin, phase: .invalid)
        }
        let night = clampedKelvin(schedule.nightKelvin)
        let cycle = wrapped(schedule.endMinute - schedule.startMinute)
        let elapsed = wrapped(minute - schedule.startMinute)
        // Past the end of the window is plain daylight.
        guard elapsed < cycle else { return State(kelvin: neutralKelvin, phase: .day) }
        let ramp = effectiveTransition(schedule)
        guard ramp > 0 else { return State(kelvin: night, phase: .night) }
        if elapsed < ramp {
            let progress = Double(elapsed) / Double(ramp)
            return State(kelvin: interpolate(from: neutralKelvin, to: night, progress: progress),
                         phase: .warming)
        }
        if elapsed > cycle - ramp {
            let progress = Double(elapsed - (cycle - ramp)) / Double(ramp)
            return State(kelvin: interpolate(from: night, to: neutralKelvin, progress: progress),
                         phase: .cooling)
        }
        return State(kelvin: night, phase: .night)
    }

    /// A straight line between two temperatures, clamped at the ends so a
    /// progress value outside 0...1 can never overshoot into an invalid target.
    static func interpolate(from start: Double, to end: Double, progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return start + (end - start) * clamped
    }

    // MARK: - Colour

    /// Relative channel gains for a colour temperature, normalised so the
    /// neutral temperature is exactly (1, 1, 1) and therefore a byte-for-byte
    /// no-op on the display's captured curve.
    ///
    /// The raw curve is Tanner Helland's approximation of a black body, which is
    /// accurate enough over 1900...6500 K for a display tint. Blue bottoms out
    /// at zero around 1900 K in that approximation, so it is floored rather than
    /// allowed to delete a channel.
    static func gains(forKelvin kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let temperature = clampedKelvin(kelvin)
        let raw = rawChannels(temperature)
        let white = rawChannels(neutralKelvin)
        let red = white.red > 0 ? raw.red / white.red : 1
        let green = white.green > 0 ? raw.green / white.green : 1
        let blue = white.blue > 0 ? raw.blue / white.blue : 1
        return (red: min(max(red, 0), 1),
                green: min(max(green, 0), 1),
                blue: min(max(blue, 0.02), 1))
    }

    /// The unnormalised black-body approximation, in 0...255 per channel.
    static func rawChannels(_ kelvin: Double) -> (red: Double, green: Double, blue: Double) {
        let temperature = clampedKelvin(kelvin) / 100
        let red: Double
        if temperature <= 66 {
            red = 255
        } else {
            red = 329.698727446 * pow(temperature - 60, -0.1332047592)
        }
        let green: Double
        if temperature <= 66 {
            green = 99.4708025861 * log(temperature) - 161.1195681661
        } else {
            green = 288.1221695283 * pow(temperature - 60, -0.0755148492)
        }
        let blue: Double
        if temperature >= 66 {
            blue = 255
        } else if temperature <= 19 {
            blue = 0
        } else {
            blue = 138.5177312231 * log(temperature - 10) - 305.0447927307
        }
        return (red: min(max(red, 0), 255),
                green: min(max(green, 0), 255),
                blue: min(max(blue, 0), 255))
    }

    /// One channel of a gamma table, multiplied by its gain. Values are left
    /// unclamped, like the software-dim path: the captured table already sits
    /// inside the display's range, so a gain no greater than one keeps it there.
    static func tintedTable(_ table: [Float], gain: Double) -> [Float] {
        guard gain < 0.9999 else { return table }
        let factor = Float(max(gain, 0))
        return table.map { $0 * factor }
    }

    // MARK: - Displays

    /// What the service knows about one display, without CoreGraphics.
    struct Display: Equatable {
        let id: UInt32
        let fingerprint: String
    }

    enum DisplayAction: Equatable {
        /// The display should show the current target.
        case apply
        /// The display's captured curve must go back exactly.
        case restore
        /// Nothing to do; the display is already in the right state.
        case none
    }

    /// Decides, per display, whether to tint, restore or leave it alone. A
    /// neutral target restores anything this app tinted, which is what makes
    /// disable, sunrise and a manual "off" all converge on a neutral screen.
    static func actions(displays: [Display],
                        tinted: Set<UInt32>,
                        enabled: Bool,
                        kelvin: Double) -> [(id: UInt32, action: DisplayAction)] {
        let warm = enabled && isWarm(kelvin)
        return displays.map { display in
            let isTinted = tinted.contains(display.id)
            if warm { return (display.id, .apply) }
            return (display.id, isTinted ? .restore : .none)
        }
    }

    /// Every display this app tinted, in a stable order, for the display-change
    /// path. A number that has just disappeared is included on purpose: its
    /// tint can still be live on the monitor it was written to, and restoring
    /// before forgetting is what keeps a re-plugged screen neutral.
    static func tintsToRestore(_ tinted: Set<UInt32>) -> [UInt32] {
        tinted.sorted()
    }
}
