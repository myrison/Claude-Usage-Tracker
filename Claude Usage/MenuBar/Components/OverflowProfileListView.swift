//
//  OverflowProfileListView.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-08-07.
//

import SwiftUI

/// One row in the overflow profile list: a profile's name and its current
/// usage percentage, with the exact text `MenuBarManager` already renders
/// for a status item's accessibility label (see
/// `ProviderMenuPresentationBuilder`/`ProviderMetricPresentation`), so this
/// list never invents a second source of truth for "what percentage is
/// this profile at".
struct OverflowProfileRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let percentageText: String
}

/// Content of the popover shown when clicking the "+N" overflow status
/// item created once more than four profiles are selected for menu bar
/// display (see `StatusBarUIManager.splitForOverflow`). Lists every
/// profile that didn't get its own status item and lets the user click
/// through to it exactly like clicking that profile's own status item
/// would — same `onSelect` contract as `AccountChipView`'s tap handler.
struct OverflowProfileListView: View {
    let rows: [OverflowProfileRow]
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverDesign.sectionSpacing) {
            PopoverSectionHeader(
                title: ProviderUILocalization.text(
                    "menubar.overflow.header",
                    fallback: "More Profiles"
                )
            )
            VStack(spacing: 4) {
                ForEach(rows) { row in
                    OverflowProfileRowButton(row: row) {
                        onSelect(row.id)
                    }
                }
            }
        }
        .padding(PopoverDesign.outerInset)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: PopoverDesign.width)
    }
}

private struct OverflowProfileRowButton: View {
    let row: OverflowProfileRow
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(row.name)
                    .font(PopoverDesign.rowTitleFont)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(row.percentageText)
                    .font(PopoverDesign.valueFont)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovering
                            ? PopoverDesign.hoverFill
                            : PopoverDesign.cardFill
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(row.name), \(row.percentageText)")
    }
}
