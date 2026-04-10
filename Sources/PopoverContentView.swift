import SwiftUI

let claudeColor = Color(red: 0.851, green: 0.467, blue: 0.337)

struct PopoverContentView: View {
    @ObservedObject var dataProvider: ClaudeDataProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            Divider()

            if dataProvider.recentSessions.isEmpty {
                noSessionView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(dataProvider.recentSessions) { session in
                            sessionCard(session)
                            if session.id != dataProvider.recentSessions.last?.id {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 440)
            }

            if let data = dataProvider.liveData {
                Divider()
                rateLimitsSection(data: data)
            }

            Divider()
            footerSection
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "terminal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(claudeColor)
            Text("Claude Code")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("Last 24h")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Session Card

    private func sessionCard(_ session: RecentSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Project name + status
            HStack(spacing: 6) {
                Circle()
                    .fill(session.isActive ? claudeColor : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)

                Text(session.projectName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Text(session.entrypointLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(claudeColor.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(claudeColor.opacity(0.1))
                    .cornerRadius(3)

                Text(timeAgo(session.lastActivity))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Context bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressBarView(
                    percentage: session.remainingPercentage,
                    height: 10,
                    showSegments: false
                )

                HStack {
                    Text("\(session.remainingPercentage)% remaining")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(session.isActive ? .primary : .secondary)

                    Spacer()

                    Text(formatTokens(session.contextUsedTokens) + " used")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            // Meta row
            if session.messageCount > 0 || session.isActive {
                HStack(spacing: 10) {
                    if session.messageCount > 0 {
                        Label("\(session.messageCount) msgs", systemImage: "bubble.left")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    if session.isActive, let live = dataProvider.liveData, live.sessionId == session.id {
                        Label(String(format: "$%.2f", live.totalCost), systemImage: "dollarsign.circle")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if session.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(claudeColor)
                            .tracking(0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(session.isActive ? claudeColor.opacity(0.03) : Color.clear)
    }

    // MARK: - Rate Limits

    private func rateLimitsSection(data: LiveData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RATE LIMITS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)

            HStack(spacing: 16) {
                rateLimitPill(
                    label: "5h",
                    remaining: max(100 - data.rateLimits.fiveHourUsed, 0),
                    resetsAt: data.rateLimits.fiveHourResetsAt
                )
                rateLimitPill(
                    label: "7d",
                    remaining: max(100 - data.rateLimits.sevenDayUsed, 0),
                    resetsAt: data.rateLimits.sevenDayResetsAt
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func rateLimitPill(label: String, remaining: Int, resetsAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Text("\(remaining)% left")
                    .font(.system(size: 10))
                    .foregroundColor(claudeColor)
            }
            ProgressBarView(percentage: remaining, height: 4, showSegments: false)
                .frame(width: 120)
        }
    }

    // MARK: - No Session

    private var noSessionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No sessions in the last 24h")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: { dataProvider.refresh() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        let hours = minutes / 60

        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let percentage: Int
    let height: CGFloat
    let showSegments: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))

                if percentage > 0 {
                    Rectangle()
                        .fill(claudeColor)
                        .frame(width: max(geometry.size.width * CGFloat(percentage) / 100, 2))
                }

                if showSegments {
                    ForEach([25, 50, 75], id: \.self) { mark in
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 0.5)
                            .offset(x: geometry.size.width * CGFloat(mark) / 100)
                    }
                }
            }
        }
        .frame(height: height)
    }
}
