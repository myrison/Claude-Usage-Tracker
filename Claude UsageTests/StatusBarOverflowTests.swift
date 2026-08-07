//
//  StatusBarOverflowTests.swift
//  Claude UsageTests
//
//  Created by Claude Code on 2026-08-07.
//

import AppKit
import UsageCore
import XCTest
@testable import Claude_Usage

@MainActor
final class StatusBarOverflowTests: HostedAppTestCase {
    private final class MenuTarget: NSObject {
        @objc func toggle() {}
    }

    private func makeProfiles(_ count: Int) -> [Profile] {
        (0..<count).map {
            Profile(name: "Profile \($0)")
        }
    }

    // MARK: - splitForOverflow (pure logic)

    func testUpToFourProfilesNeverOverflow() {
        for count in 0...4 {
            let profiles = makeProfiles(count)
            let plan = StatusBarUIManager.splitForOverflow(profiles)
            XCTAssertEqual(
                plan.individual.count,
                count,
                "\(count) profiles must all get their own item"
            )
            XCTAssertTrue(
                plan.overflow.isEmpty,
                "\(count) profiles must never produce an overflow item"
            )
        }
    }

    func testMoreThanFourProfilesOverflowsPastTheFirstThree() {
        let profiles = makeProfiles(7)
        let plan = StatusBarUIManager.splitForOverflow(profiles)
        XCTAssertEqual(plan.individual.count, 3)
        XCTAssertEqual(plan.overflow.count, 4)
        XCTAssertEqual(
            plan.individual.map(\.id),
            Array(profiles.prefix(3)).map(\.id),
            "The first three profiles, in order, keep their own item"
        )
        XCTAssertEqual(
            plan.overflow.map(\.id),
            Array(profiles.dropFirst(3)).map(\.id)
        )
    }

    // MARK: - StatusBarUIManager integration
    //
    // Every manager here is process-retained (matching the convention
    // established by `ProviderMenuPresentationTests`) and torn down with
    // `defer { manager.cleanup() }`: letting a `StatusBarUIManager` that
    // owns real `NSStatusItem`s be deallocated mid-test — instead of
    // cleaned up while still alive — corrupts AppKit's status-bar state and
    // aborts the test process.

    func testSetupMultiProfileWithFourOrFewerCreatesNoOverflowItem() {
        let manager = retain(StatusBarUIManager())
        defer { manager.cleanup() }
        let target = MenuTarget()
        manager.setupMultiProfile(
            profiles: makeProfiles(4),
            target: target,
            action: #selector(MenuTarget.toggle)
        )
        XCTAssertNil(manager.overflowButton)
        XCTAssertTrue(manager.overflowProfileIDs.isEmpty)
    }

    func testSetupMultiProfileWithSevenCreatesThreeIndividualPlusOverflow() {
        let manager = retain(StatusBarUIManager())
        defer { manager.cleanup() }
        let target = MenuTarget()
        let profiles = makeProfiles(7)
        manager.setupMultiProfile(
            profiles: profiles,
            target: target,
            action: #selector(MenuTarget.toggle)
        )

        for profile in profiles.prefix(3) {
            XCTAssertNotNil(
                manager.button(for: profile.id),
                "\(profile.name) should have its own status item"
            )
        }
        for profile in profiles.dropFirst(3) {
            XCTAssertNil(
                manager.button(for: profile.id),
                "\(profile.name) must not get its own status item once "
                    + "overflowed"
            )
        }

        XCTAssertNotNil(manager.overflowButton)
        XCTAssertEqual(
            manager.overflowProfileIDs,
            profiles.dropFirst(3).map(\.id)
        )
        XCTAssertTrue(manager.isOverflowButton(manager.overflowButton))
        XCTAssertEqual(
            manager.autosaveName(for: manager.overflowButton),
            "claude-usage-tracker.overflow"
        )
    }

    func testUpdateMultiProfileConfigurationAddsAndRemovesOverflow() {
        let manager = retain(StatusBarUIManager())
        defer { manager.cleanup() }
        let target = MenuTarget()
        let action = #selector(MenuTarget.toggle)

        // Start under the threshold: no overflow item.
        manager.setupMultiProfile(
            profiles: makeProfiles(3),
            target: target,
            action: action
        )
        XCTAssertNil(manager.overflowButton)

        // Grow past the threshold: overflow item must appear.
        let grown = makeProfiles(7)
        manager.updateMultiProfileConfiguration(
            profiles: grown,
            target: target,
            action: action
        )
        XCTAssertNotNil(manager.overflowButton)
        XCTAssertEqual(manager.overflowProfileIDs.count, 4)

        // Shrink back under the threshold: overflow item must be removed.
        manager.updateMultiProfileConfiguration(
            profiles: Array(grown.prefix(2)),
            target: target,
            action: action
        )
        XCTAssertNil(manager.overflowButton)
        XCTAssertTrue(manager.overflowProfileIDs.isEmpty)
    }

    func testCleanupRemovesOverflowItem() {
        let manager = retain(StatusBarUIManager())
        let target = MenuTarget()
        manager.setupMultiProfile(
            profiles: makeProfiles(7),
            target: target,
            action: #selector(MenuTarget.toggle)
        )
        XCTAssertNotNil(manager.overflowButton)
        manager.cleanup()
        XCTAssertNil(manager.overflowButton)
        XCTAssertTrue(manager.overflowProfileIDs.isEmpty)
    }

    // MARK: - MenuBarManager.overflowProfileRows (pure logic)

    func testOverflowProfileRowsMatchOrderAndPercentage() {
        let profiles = makeProfiles(2)
        var withUsage = ClaudeUsage.empty
        withUsage.sessionPercentage = 42
        withUsage.sessionResetTime = Date().addingTimeInterval(3_600)
        var claudeProfile = profiles[0]
        claudeProfile.claudeUsage = withUsage

        let rows = MenuBarManager.overflowProfileRows(
            profileIDs: [profiles[1].id, profiles[0].id],
            profiles: [claudeProfile, profiles[1]],
            snapshots: [:],
            activeProfileID: nil
        )

        XCTAssertEqual(rows.map(\.id), [profiles[1].id, profiles[0].id])
        XCTAssertEqual(rows[0].name, profiles[1].name)
        XCTAssertEqual(rows[1].name, claudeProfile.name)
    }

    func testOverflowProfileRowsSkipsUnknownProfileIDs() {
        let profiles = makeProfiles(1)
        let missingID = UUID()
        let rows = MenuBarManager.overflowProfileRows(
            profileIDs: [profiles[0].id, missingID],
            profiles: profiles,
            snapshots: [:],
            activeProfileID: nil
        )
        XCTAssertEqual(rows.map(\.id), [profiles[0].id])
    }
}
