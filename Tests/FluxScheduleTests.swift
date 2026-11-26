// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The warm-colour schedule, its boundaries and its restore decisions, run
/// against `FluxSupport` sliced verbatim into `build/generated-tests/`.
///
/// Fixtures are deliberately round numbers: sunset at 18:00, sunrise at 06:00,
/// a one-hour ramp, a 3000 K night. Nothing here reads the clock, a display or
/// a preference, so a failure is always the arithmetic and never the machine.
enum FluxScheduleTests {
    /// 18:00 to 06:00, a 60 minute ramp at each end, 3000 K at night.
    private static let overnight = FluxSupport.Schedule(
        startMinute: 18 * 60, endMinute: 6 * 60,
        transitionMinutes: 60, nightKelvin: 3000, mode: .sunsetToSunrise)

    /// 08:00 to 17:00, the daylight-only schedule a fixed-time user might set.
    private static let daytime = FluxSupport.Schedule(
        startMinute: 8 * 60, endMinute: 17 * 60,
        transitionMinutes: 60, nightKelvin: 3000, mode: .fixed)

    private static func state(_ minute: Int,
                              enabled: Bool = true,
                              override: Double? = nil) -> FluxSupport.State {
        state(minute, overnight, enabled: enabled, override: override)
    }

    private static func state(_ minute: Int,
                              _ schedule: FluxSupport.Schedule?,
                              enabled: Bool = true,
                              override: Double? = nil) -> FluxSupport.State {
        FluxSupport.state(minuteOfDay: minute, schedule: schedule,
                          enabled: enabled, overrideKelvin: override)
    }

    static func run(_ suite: TestSuite) {
        suite.run("flux-schedule") { boundaries(suite) }
        suite.run("flux-override") { overrideBeatsSchedule(suite) }
        suite.run("flux-invalid") { malformedSchedules(suite) }
        suite.run("flux-colour") { colourMaths(suite) }
        suite.run("flux-restore") { restoreDecisions(suite) }
    }

    private static func boundaries(_ suite: TestSuite) {
        // Exactly at sunset is still daylight, and the ramp has just started.
        let sunset = state(18 * 60)
        suite.expect(sunset.phase == .warming, "exactly at sunset the schedule is warming")
        suite.expectClose(sunset.kelvin, FluxSupport.neutralKelvin,
                          "exactly at sunset the picture is still neutral")

        // Halfway through the one-hour ramp.
        let halfRamp = state(18 * 60 + 30)
        suite.expectClose(halfRamp.kelvin, 4750, "halfway up the ramp is halfway between 6500 and 3000")

        // One minute either side of the ramp's end.
        suite.expect(state(19 * 60).phase == .night && state(19 * 60).kelvin == 3000,
                     "one hour after sunset the night target holds")
        suite.expectClose(state(18 * 60 + 59).kelvin, 6500 - 3500 * 59.0 / 60.0,
                          "the last minute of the warming ramp is just short of the target")

        // The night holds through midnight and most of the small hours.
        suite.expect(state(23 * 60).phase == .night && state(3 * 60).phase == .night,
                     "the night target holds across midnight")
        suite.expectClose(state(3 * 60).kelvin, 3000, "the night target is the chosen temperature")

        // Cooling starts exactly at sunrise minus the ramp.
        let coolingStart = state(5 * 60)
        suite.expect(coolingStart.phase == .night && coolingStart.kelvin == 3000,
                     "the cooling ramp begins from the night target")
        suite.expect(state(5 * 60 + 1).phase == .cooling, "one minute later the picture is cooling")
        suite.expectClose(state(5 * 60 + 1).kelvin, 3000 + 3500.0 / 60.0,
                          "cooling moves toward neutral one ramp step at a time")

        // Exactly at sunrise is neutral again, and the phase is plain day.
        let sunrise = state(6 * 60)
        suite.expect(sunrise.phase == .day, "exactly at sunrise the window is over")
        suite.expectClose(sunrise.kelvin, FluxSupport.neutralKelvin,
                          "exactly at sunrise the picture is neutral")
        suite.expect(state(6 * 60 + 1).phase == .day, "after sunrise stays neutral")
        suite.expect(state(12 * 60).phase == .day && state(12 * 60).kelvin == 6500,
                     "the middle of the day is neutral")

        // A window that does not cross midnight follows the same rules.
        suite.expect(state(8 * 60, daytime).phase == .warming, "a daytime window starts at its own edge")
        suite.expect(state(9 * 60, daytime).phase == .night, "a daytime window reaches its night target")
        suite.expect(state(16 * 60, daytime).phase == .night,
                     "a daytime window holds its target up to the cooling boundary")
        suite.expect(state(16 * 60 + 1, daytime).phase == .cooling,
                     "a daytime window cools into its end")
        suite.expect(state(17 * 60, daytime).phase == .day
                     && state(17 * 60, daytime).kelvin == 6500,
                     "a daytime window is neutral exactly at its end")

        // A zero ramp is a step, not an invalid schedule.
        let step = FluxSupport.Schedule(startMinute: 18 * 60, endMinute: 6 * 60,
                                        transitionMinutes: 0, nightKelvin: 3000)
        suite.expect(state(18 * 60, step).phase == .night && state(18 * 60, step).kelvin == 3000,
                     "a zero ramp steps straight to the night target at sunset")

        // Clock folding is part of the contract: minutes after midnight, wrapped.
        suite.expect(FluxSupport.minuteOfDay(hour: 18, minute: 30) == 1110,
                     "a clock time becomes minutes after midnight")
        suite.expect(FluxSupport.minuteOfDay(hour: 25, minute: 0) == 60,
                     "an hour past midnight folds into the next day")
        suite.expect(FluxSupport.minuteOfDay(hour: -1, minute: 0) == 1380,
                     "an hour before midnight folds into the previous day")
    }

    private static func overrideBeatsSchedule(_ suite: TestSuite) {
        // A manual choice wins over a schedule that is holding the night target.
        let manual = state(23 * 60, overnight, override: 2700)
        suite.expect(manual.phase == .override, "a manual choice is reported as an override")
        suite.expectClose(manual.kelvin, 2700, "a manual choice wins over the night target")
        suite.expect(state(23 * 60, overnight, override: 2700).kelvin
                     != state(23 * 60, overnight).kelvin,
                     "the manual choice is actually different from the schedule's answer")

        // It also warms a schedule that is sitting in daylight.
        suite.expect(state(12 * 60, overnight, override: 2500).kelvin == 2500,
                     "a manual choice warms a display the schedule left neutral")

        // A manual choice of neutral is a restore, not a warm target.
        let neutralOverride = state(23 * 60, overnight, override: 6500)
        suite.expect(neutralOverride.phase == .override
                     && !FluxSupport.isWarm(neutralOverride.kelvin),
                     "a manual choice of neutral asks for no tint")

        // Out-of-range input is clamped to a temperature a display can take.
        suite.expect(state(23 * 60, overnight, override: 1000).kelvin == FluxSupport.minimumKelvin,
                     "a manual choice below the floor is raised to the floor")
        suite.expect(state(23 * 60, overnight, override: 9000).kelvin == FluxSupport.neutralKelvin,
                     "a manual choice above neutral is lowered to neutral")

        // Disabled beats both the schedule and the override.
        let off = state(23 * 60, overnight, enabled: false, override: 2500)
        suite.expect(off.phase == .off && off.kelvin == FluxSupport.neutralKelvin,
                     "switching the feature off is neutral even with a manual choice saved")
        suite.expect(!FluxSupport.isWarm(off.kelvin), "the disabled state never asks for a tint")
    }

    private static func malformedSchedules(_ suite: TestSuite) {
        // No schedule at all.
        let empty = state(23 * 60, nil)
        suite.expect(empty.phase == .invalid && empty.kelvin == FluxSupport.neutralKelvin,
                     "an absent schedule gives up to neutral")

        // Equal edges describe no window.
        let equal = FluxSupport.Schedule(startMinute: 18 * 60, endMinute: 18 * 60,
                                         transitionMinutes: 60, nightKelvin: 3000)
        suite.expect(!FluxSupport.isValid(equal), "equal edges are not a window")
        suite.expect(state(23 * 60, equal).phase == .invalid
                     && state(23 * 60, equal).kelvin == 6500,
                     "equal edges stay neutral")

        // A negative ramp has no direction.
        let negative = FluxSupport.Schedule(startMinute: 18 * 60, endMinute: 6 * 60,
                                            transitionMinutes: -1, nightKelvin: 3000)
        suite.expect(!FluxSupport.isValid(negative), "a negative ramp is malformed")

        // A ramp longer than half the window would overlap itself.
        let overlapping = FluxSupport.Schedule(startMinute: 8 * 60, endMinute: 17 * 60,
                                               transitionMinutes: 271, nightKelvin: 3000)
        suite.expect(!FluxSupport.isValid(overlapping),
                     "a ramp longer than half the window is malformed")
        let longest = FluxSupport.Schedule(startMinute: 8 * 60, endMinute: 17 * 60,
                                           transitionMinutes: 270, nightKelvin: 3000)
        suite.expect(FluxSupport.isValid(longest), "a ramp of exactly half the window is allowed")

        // A non-finite target cannot be turned into a gain.
        let notANumber = FluxSupport.Schedule(startMinute: 18 * 60, endMinute: 6 * 60,
                                              transitionMinutes: 60, nightKelvin: .nan)
        suite.expect(!FluxSupport.isValid(notANumber) && state(23 * 60, notANumber).phase == .invalid,
                     "a non-finite target is malformed")

        // A target outside the usable range is clamped, not discarded.
        let tooWarm = FluxSupport.Schedule(startMinute: 18 * 60, endMinute: 6 * 60,
                                           transitionMinutes: 60, nightKelvin: 1000)
        suite.expect(state(23 * 60, tooWarm).kelvin == FluxSupport.minimumKelvin,
                     "a target below the floor is clamped to the floor")

        // An empty schedule also restores: neutral is never a tint.
        suite.expect(!FluxSupport.isWarm(state(23 * 60, nil).kelvin),
                     "a malformed schedule never leaves a display tinted")
    }

    private static func colourMaths(_ suite: TestSuite) {
        // Neutral is an exact no-op, so restore and "warm at 6500" agree.
        let neutral = FluxSupport.gains(forKelvin: 6500)
        suite.expectClose(neutral.red, 1, "neutral gain red is exactly one")
        suite.expectClose(neutral.green, 1, "neutral gain green is exactly one")
        suite.expectClose(neutral.blue, 1, "neutral gain blue is exactly one")

        // Warmth removes blue first, then green, and never lowers red.
        let warm = FluxSupport.gains(forKelvin: 3400)
        suite.expect(warm.red >= warm.green && warm.green >= warm.blue,
                     "warmth is ordered red, green, blue")
        suite.expectClose(warm.red, 1, "warmth keeps the red channel whole")
        suite.expect(warm.blue > 0.3 && warm.blue < 0.9,
                     "a 3400 K night keeps some blue rather than deleting it")

        // Blue falls monotonically as the temperature drops.
        let low = FluxSupport.gains(forKelvin: 2700).blue
        let mid = FluxSupport.gains(forKelvin: 3400).blue
        let high = FluxSupport.gains(forKelvin: 5000).blue
        suite.expect(low < mid && mid < high && high < 1,
                     "blue rises with temperature and is below one below neutral")

        // The floor and the ceiling clamp instead of producing a channel of zero.
        suite.expectClose(FluxSupport.gains(forKelvin: 1000).blue,
                          FluxSupport.gains(forKelvin: 1900).blue,
                          "below the floor the gain is the floor's gain")
        suite.expect(FluxSupport.gains(forKelvin: 1900).blue >= 0.02,
                     "the floor keeps a visible amount of blue")
        suite.expectClose(FluxSupport.gains(forKelvin: 9000).blue, 1,
                          "above neutral the gain is neutral")

        // A table is scaled per channel, and a gain of one leaves it untouched.
        let table: [Float] = [0, 0.25, 0.5, 1]
        suite.expect(FluxSupport.tintedTable(table, gain: 1) == table,
                     "a gain of one returns the table untouched")
        let halved = FluxSupport.tintedTable(table, gain: 0.5)
        suite.expect(halved == [0, 0.125, 0.25, 0.5],
                     "a gain of one half scales every entry")
        suite.expect(FluxSupport.tintedTable(table, gain: 0) == [0, 0, 0, 0],
                     "a gain of zero blacks the channel")
        suite.expect(FluxSupport.tintedTable([], gain: 0.5).isEmpty,
                     "an empty table stays empty")

        // The ramp itself, including values outside the endpoints.
        suite.expectClose(FluxSupport.interpolate(from: 6500, to: 3000, progress: 0), 6500,
                          "the ramp starts at the neutral temperature")
        suite.expectClose(FluxSupport.interpolate(from: 6500, to: 3000, progress: 0.5), 4750,
                          "the ramp's midpoint is halfway")
        suite.expectClose(FluxSupport.interpolate(from: 6500, to: 3000, progress: 1), 3000,
                          "the ramp ends at the night temperature")
        suite.expectClose(FluxSupport.interpolate(from: 6500, to: 3000, progress: -1), 6500,
                          "progress below the start is clamped")
        suite.expectClose(FluxSupport.interpolate(from: 6500, to: 3000, progress: 2), 3000,
                          "progress past the end is clamped")
    }

    private static func restoreDecisions(_ suite: TestSuite) {
        let night = 3000.0
        let displays = [FluxSupport.Display(id: 1, fingerprint: "a:1:1"),
                        FluxSupport.Display(id: 2, fingerprint: "b:2:2")]

        // Warm and enabled: both displays are told to show the target.
        let warm = FluxSupport.actions(displays: displays, tinted: [1], enabled: true, kelvin: night)
        suite.expect(warm.count == 2 && warm.allSatisfy { $0.action == .apply },
                     "a warm target is applied to every display")

        // Disabled: a tinted display is restored and an untouched one is left be.
        let off = FluxSupport.actions(displays: displays, tinted: [1], enabled: false, kelvin: night)
        suite.expect(off.first { $0.id == 1 }?.action == .restore,
                     "disabling restores a display this app tinted")
        suite.expect(off.first { $0.id == 2 }?.action == FluxSupport.DisplayAction.none,
                     "disabling never writes to a display this app did not tint")

        // Sunrise (a neutral target with the feature still on) also restores.
        let sunrise = FluxSupport.actions(displays: displays, tinted: [1, 2], enabled: true,
                                          kelvin: FluxSupport.neutralKelvin)
        suite.expect(sunrise.allSatisfy { $0.action == .restore },
                     "a neutral target restores every tinted display")

        // An invalid schedule resolves to neutral, so it restores too.
        let invalid = state(23 * 60, nil)
        let invalidPlan = FluxSupport.actions(displays: displays, tinted: [2], enabled: true,
                                              kelvin: invalid.kelvin)
        suite.expect(invalid.phase == .invalid && invalidPlan.first { $0.id == 2 }?.action == .restore,
                     "a malformed schedule restores rather than leaving a tint on")

        // Nothing to do on an empty display list.
        suite.expect(FluxSupport.actions(displays: [], tinted: [1], enabled: true, kelvin: night).isEmpty,
                     "an empty display list asks for no work")

        // A display change restores every tinted number first, including one
        // that has already gone away, then applies the target to the new list.
        let stale = FluxSupport.tintsToRestore([9, 3])
        suite.expect(stale == [3, 9], "restore order is stable, not set order")
        let afterChange = FluxSupport.actions(
            displays: [FluxSupport.Display(id: 9, fingerprint: "x:9:9"),
                       FluxSupport.Display(id: 12, fingerprint: "y:12:12")],
            tinted: [9], enabled: true, kelvin: night)
        suite.expect(afterChange.allSatisfy { $0.action == .apply },
                     "after a display change both the survivor and the newcomer show the target")

        // The setting's default schedule is a usable one: a malformed default
        // would silently disable the feature at every launch.
        let shipped = FluxSupport.Schedule(startMinute: 18 * 60 + 30, endMinute: 7 * 60,
                                           transitionMinutes: 60, nightKelvin: 3400,
                                           mode: .sunsetToSunrise)
        suite.expect(FluxSupport.isValid(shipped), "the shipped default schedule is valid")
        suite.expectClose(state(22 * 60, shipped).kelvin, 3400,
                          "the shipped default reaches its 3400 K night target")
        suite.expect(state(12 * 60, shipped).phase == .day,
                     "the shipped default leaves the day alone")
    }
}
