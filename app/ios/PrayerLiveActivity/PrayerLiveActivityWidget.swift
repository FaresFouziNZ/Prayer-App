import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity itself (SRS FR-LA-01..09, §2.7's "iOS — ActivityKit"
/// table). Add this file's target membership to `PrayerLiveActivity` only —
/// it imports ActivityKit/WidgetKit UI that has no place in the main app.
struct PrayerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(
                    context.state.phase == .closing
                        ? Color.red.opacity(0.12)
                        : Color(.systemBackground)
                )
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PrayerDisplayNames.arabic(for: context.attributes))
                            .font(.headline)
                        Text(PrayerDisplayNames.transliteration(for: context.attributes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: countdownRange(context.state), countsDown: true)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(context.state.phase == .closing ? .red : .primary)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.phase == .closing && !context.state.logged {
                        LogActionsRow(attributes: context.attributes)
                    } else {
                        Text(phaseLabel(context.state.phase))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: PrayerDisplayNames.systemImageName(for: context.attributes.prayer))
            } compactTrailing: {
                Text(timerInterval: countdownRange(context.state), countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                Text(timerInterval: countdownRange(context.state), countsDown: true)
                    .font(.caption2.monospacedDigit())
            }
        }
    }

    /// `Text(timerInterval:)` needs a `ClosedRange<Date>`; anchoring the
    /// start at the countdown target itself when it's already passed (a
    /// late catch-up render, e.g. right after `.request`) keeps the range
    /// valid instead of crashing on start > end.
    private func countdownRange(_ state: PrayerActivityAttributes.ContentState) -> ClosedRange<Date> {
        let target = state.countdownTarget
        let start = min(Date.now, target)
        return start...target
    }

    private func phaseLabel(_ phase: PrayerActivityAttributes.ContentState.Phase) -> String {
        switch phase {
        case .iqamah: return "Iqamah in"
        case .window: return "Window closes in"
        case .closing: return "Closing soon"
        }
    }
}

private struct LockScreenView: View {
    let attributes: PrayerActivityAttributes
    let state: PrayerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PrayerDisplayNames.arabic(for: attributes))
                        .font(.title3.bold())
                    Text(PrayerDisplayNames.transliteration(for: attributes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerInterval: countdownRange, countsDown: true)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(state.phase == .closing ? .red : .primary)
                    Text(phaseCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if state.phase == .closing && !state.logged {
                LogActionsRow(attributes: attributes)
            }
        }
        .padding()
    }

    private var countdownRange: ClosedRange<Date> {
        let target = state.countdownTarget
        let start = min(Date.now, target)
        return start...target
    }

    private var phaseCaption: String {
        switch state.phase {
        case .iqamah: return "until Iqamah"
        case .window: return "window ends"
        case .closing: return "ending soon"
        }
    }
}

private struct LogActionsRow: View {
    let attributes: PrayerActivityAttributes

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: LogPrayerIntent(
                prayer: attributes.prayer,
                date: attributes.date,
                status: .jamaah
            )) {
                Text("Jama'ah")
                    .frame(maxWidth: .infinity)
            }
            Button(intent: LogPrayerIntent(
                prayer: attributes.prayer,
                date: attributes.date,
                status: .alone
            )) {
                Text("Alone")
                    .frame(maxWidth: .infinity)
            }
            Button(intent: LogPrayerIntent(
                prayer: attributes.prayer,
                date: attributes.date,
                status: .notYet
            )) {
                Text("Not yet")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
        .tint(.red)
    }
}
