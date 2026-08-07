//
//  StatusItemPositionSanitizer.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-08-07.
//

import Cocoa

/// Removes AppKit-persisted `NSStatusItem` positions that have gone stale.
///
/// Every status item created with an `autosaveName` (see
/// `StatusBarUIManager`) has its preferred position persisted by AppKit
/// under `"NSStatusItem Preferred Position <autosaveName>"` in the app's own
/// `UserDefaults` domain. That key is keyed to the bundle ID and survives
/// app reinstalls. If the user later removes a monitor, or otherwise
/// changes their screen layout, a saved position can point at an x
/// coordinate no screen covers anymore. AppKit then has no window rect to
/// resolve for that item, which is exactly the failure a third-party menu
/// bar manager (Ice) surfaced as `CGSGetScreenRectForWindow failed with
/// error 1000` / `EventError(code: invalidItem)` — six items stranded at
/// x ≈ 6633-6923 and one at 11728 on an 1800-point-wide screen, left over
/// from a prior wide multi-monitor setup.
///
/// Running this once at launch, before any status item is created, clears
/// the stale keys so AppKit falls back to placing the item fresh instead of
/// inheriting an unreachable coordinate. It has no effect once an item for
/// that `autosaveName` already exists — AppKit reads the saved position
/// only at creation time.
enum StatusItemPositionSanitizer {
    /// The key prefix AppKit persists for every status item with an
    /// `autosaveName`. The value is a single `Double`: the item's preferred
    /// x position in the *global* menu-bar coordinate space (spanning every
    /// attached screen), not a per-screen-relative coordinate.
    static let keyPrefix = "NSStatusItem Preferred Position "

    /// Pure decision logic, independent of `UserDefaults`/`NSScreen`, so it
    /// is exercised directly by tests with plain dictionaries and rects.
    ///
    /// Returns the subset of `savedDefaults`'s keys (prefixed with
    /// `keyPrefix`) whose saved x position falls on none of `screenFrames`.
    ///
    /// Each screen is tested separately rather than collapsing them into one
    /// `minX...maxX` span. Displays need not be contiguous in the global
    /// coordinate space — two monitors can sit with a gap between them — and
    /// a span would report a position inside that gap as reachable, leaving
    /// the item exactly as invisible as before while claiming it was fine.
    ///
    /// Returns an empty array — never treats anything as stale — when
    /// `screenFrames` is empty. We cannot distinguish "off-screen" from
    /// "on-screen" without at least one attached screen, and treating
    /// "unknown" as "off-screen" would wipe every saved position the
    /// instant a headless session (e.g. Remote Desktop before a display
    /// attaches) briefly reports zero screens.
    static func staleKeys(
        in savedDefaults: [String: Any],
        screenFrames: [CGRect]
    ) -> [String] {
        let reachableRanges = screenFrames
            .filter { $0.minX <= $0.maxX }
            .map { $0.minX...$0.maxX }
        guard !reachableRanges.isEmpty else { return [] }

        return savedDefaults.keys
            .filter { $0.hasPrefix(keyPrefix) }
            .filter { key in
                guard let number = savedDefaults[key] as? NSNumber else {
                    // Not the Double AppKit always writes for this key —
                    // leave it alone rather than guess.
                    return false
                }
                let position = CGFloat(number.doubleValue)
                return !reachableRanges.contains {
                    $0.contains(position)
                }
            }
            .sorted()
    }

    /// Removes every stale saved position from `defaults`. Call once, at
    /// launch, before any `NSStatusBar.system.statusItem(...)` is created.
    static func sanitize(
        defaults: UserDefaults,
        screens: [NSScreen]
    ) {
        let saved = defaults.dictionaryRepresentation()
        let stale = staleKeys(
            in: saved,
            screenFrames: screens.map(\.frame)
        )
        guard !stale.isEmpty else { return }

        for key in stale {
            defaults.removeObject(forKey: key)
        }

        let resetNames = stale.map {
            $0.replacingOccurrences(of: keyPrefix, with: "")
        }.joined(separator: ", ")
        LoggingService.shared.logUIEvent(
            "StatusItemPositionSanitizer: reset \(stale.count) stale "
                + "status item position(s): \(resetNames)"
        )
    }
}
