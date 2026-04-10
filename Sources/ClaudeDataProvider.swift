import Foundation
import Combine

struct SessionInfo: Identifiable {
    let id: String
    let pid: Int
    let cwd: String
    let startedAt: Date
    let entrypoint: String
    var isAlive: Bool

    var projectName: String {
        let components = cwd.split(separator: "/")
        return String(components.last ?? "Unknown")
    }

    var entrypointLabel: String {
        switch entrypoint {
        case "cli": return "CLI"
        case "claude-desktop": return "Desktop"
        default: return entrypoint
        }
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
}

struct ContextWindow {
    let size: Int
    let usedPercentage: Int
    let remainingPercentage: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
}

struct RateLimits {
    let fiveHourUsed: Int
    let fiveHourResetsAt: Date
    let sevenDayUsed: Int
    let sevenDayResetsAt: Date
}

struct LiveData {
    let sessionId: String
    let model: String
    let cwd: String
    let totalCost: Double
    let totalDuration: TimeInterval
    let contextWindow: ContextWindow
    let rateLimits: RateLimits
    let exceeds200k: Bool
}

struct RecentSession: Identifiable {
    let id: String
    let projectName: String
    let projectDir: String
    let entrypoint: String
    let startedAt: Date
    let lastActivity: Date
    let contextUsedTokens: Int
    let contextWindowSize: Int
    let usedPercentage: Int
    let remainingPercentage: Int
    let isActive: Bool
    let totalCost: Double
    let messageCount: Int

    var entrypointLabel: String {
        switch entrypoint {
        case "cli": return "CLI"
        case "claude-desktop": return "Desktop"
        default: return entrypoint
        }
    }
}

class ClaudeDataProvider: ObservableObject {
    @Published var sessions: [SessionInfo] = []
    @Published var liveData: LiveData?
    @Published var recentSessions: [RecentSession] = []
    @Published var lastRefresh: Date = Date()

    private let homeDir = FileManager.default.homeDirectoryForCurrentUser
    private var lastFullScan: Date = .distantPast

    var contextUsedPercentage: Int {
        liveData?.contextWindow.usedPercentage ?? 0
    }

    var hasActiveSession: Bool {
        !sessions.isEmpty && liveData != nil
    }

    func refresh() {
        loadSessions()
        loadLiveData()

        // Full transcript scan every 10s (heavier operation)
        if Date().timeIntervalSince(lastFullScan) > 10 {
            loadRecentSessions()
            lastFullScan = Date()
        }

        lastRefresh = Date()
    }

    // MARK: - Active Sessions

    private func loadSessions() {
        let sessionsDir = homeDir.appendingPathComponent(".claude/sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else {
            sessions = []
            return
        }

        sessions = files.compactMap { url -> SessionInfo? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String,
                  let startedAtMs = json["startedAt"] as? Double,
                  let entrypoint = json["entrypoint"] as? String
            else { return nil }

            let isAlive = kill(Int32(pid), 0) == 0
            guard isAlive else { return nil }

            return SessionInfo(
                id: sessionId,
                pid: pid,
                cwd: cwd,
                startedAt: Date(timeIntervalSince1970: startedAtMs / 1000),
                entrypoint: entrypoint,
                isAlive: isAlive
            )
        }.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Live Data

    private func loadLiveData() {
        let liveFile = homeDir.appendingPathComponent(".claude/usage-live.json")
        guard let data = try? Data(contentsOf: liveFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            liveData = nil
            return
        }

        guard let sessionId = json["session_id"] as? String,
              let modelDict = json["model"] as? [String: Any],
              let modelName = modelDict["display_name"] as? String,
              let costDict = json["cost"] as? [String: Any],
              let totalCost = costDict["total_cost_usd"] as? Double,
              let totalDurationMs = costDict["total_duration_ms"] as? Double,
              let cwDict = json["context_window"] as? [String: Any],
              let cwSize = cwDict["context_window_size"] as? Int,
              let usedPct = cwDict["used_percentage"] as? Int,
              let remainPct = cwDict["remaining_percentage"] as? Int,
              let rlDict = json["rate_limits"] as? [String: Any],
              let fiveHour = rlDict["five_hour"] as? [String: Any],
              let sevenDay = rlDict["seven_day"] as? [String: Any]
        else {
            liveData = nil
            return
        }

        let cwd = (json["workspace"] as? [String: Any])?["current_dir"] as? String ?? "Unknown"
        let usage = cwDict["current_usage"] as? [String: Any] ?? [:]

        let contextWindow = ContextWindow(
            size: cwSize,
            usedPercentage: usedPct,
            remainingPercentage: remainPct,
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0,
            cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0
        )

        let rateLimits = RateLimits(
            fiveHourUsed: fiveHour["used_percentage"] as? Int ?? 0,
            fiveHourResetsAt: Date(timeIntervalSince1970: (fiveHour["resets_at"] as? Double ?? 0)),
            sevenDayUsed: sevenDay["used_percentage"] as? Int ?? 0,
            sevenDayResetsAt: Date(timeIntervalSince1970: (sevenDay["resets_at"] as? Double ?? 0))
        )

        liveData = LiveData(
            sessionId: sessionId,
            model: modelName,
            cwd: cwd,
            totalCost: totalCost,
            totalDuration: totalDurationMs / 1000,
            contextWindow: contextWindow,
            rateLimits: rateLimits,
            exceeds200k: json["exceeds_200k_tokens"] as? Bool ?? false
        )
    }

    // MARK: - Recent Sessions (last 24h from transcripts)

    private func loadRecentSessions() {
        let projectsDir = homeDir.appendingPathComponent(".claude/projects")
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: nil
        ) else {
            recentSessions = []
            return
        }

        var found: [RecentSession] = []
        let activeSessionIds = Set(sessions.map { $0.id })

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue
            else { continue }

            let dirName = projectDir.lastPathComponent
            let projectName = extractProjectName(from: dirName)

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files {
                guard file.pathExtension == "jsonl" else { continue }

                // Skip subagent/plugin files
                let filename = file.deletingPathExtension().lastPathComponent
                if filename.hasPrefix("agent-") || filename == "skill-injections" { continue }

                // Only transcripts updated in the last 24h
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate,
                      modDate > cutoff
                else { continue }

                if let session = parseTranscript(file, projectName: projectName, lastActivity: modDate, activeIds: activeSessionIds) {
                    found.append(session)
                }
            }
        }

        // Deduplicate: if we have live data for a session, use that instead
        recentSessions = found
            .sorted { $0.lastActivity > $1.lastActivity }

        // Override active session data with live data if available
        if let live = liveData {
            if let idx = recentSessions.firstIndex(where: { $0.id == live.sessionId }) {
                let old = recentSessions[idx]
                recentSessions[idx] = RecentSession(
                    id: old.id,
                    projectName: old.projectName,
                    projectDir: live.cwd,
                    entrypoint: old.entrypoint,
                    startedAt: old.startedAt,
                    lastActivity: old.lastActivity,
                    contextUsedTokens: live.contextWindow.inputTokens + live.contextWindow.outputTokens + live.contextWindow.cacheCreationTokens + live.contextWindow.cacheReadTokens,
                    contextWindowSize: live.contextWindow.size,
                    usedPercentage: live.contextWindow.usedPercentage,
                    remainingPercentage: live.contextWindow.remainingPercentage,
                    isActive: true,
                    totalCost: live.totalCost,
                    messageCount: old.messageCount
                )
            }
        }
    }

    private func parseTranscript(_ url: URL, projectName: String, lastActivity: Date, activeIds: Set<String>) -> RecentSession? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8)
        else { return nil }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var sessionId: String?
        var entrypoint = "unknown"
        var cwd = ""
        var startedAt: Date?
        var messageCount = 0
        var totalCost: Double = 0

        // Read first lines for metadata
        for line in lines.prefix(15) {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            let msgType = json["type"] as? String ?? ""

            if msgType == "user", sessionId == nil {
                sessionId = json["sessionId"] as? String
                entrypoint = json["entrypoint"] as? String ?? "unknown"
                cwd = json["cwd"] as? String ?? ""
                if let ts = json["timestamp"] as? String {
                    startedAt = parseISO8601(ts)
                }
            }
        }

        guard let sid = sessionId else { return nil }

        // Only include Claude Desktop sessions
        guard entrypoint == "claude-desktop" else { return nil }

        // Read last lines for final context usage + message count
        var lastInputTokens = 0
        var lastCacheCreation = 0
        var lastCacheRead = 0
        var lastOutputTokens = 0

        for line in lines.suffix(30).reversed() {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            let msgType = json["type"] as? String ?? ""

            // Get message count from turn_duration entries
            if msgType == "system",
               json["subtype"] as? String == "turn_duration",
               let mc = json["messageCount"] as? Int {
                messageCount = max(messageCount, mc)
            }

            // Get last assistant usage
            if msgType == "assistant", lastCacheRead == 0 {
                if let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    lastInputTokens = usage["input_tokens"] as? Int ?? 0
                    lastCacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
                    lastCacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                    lastOutputTokens = usage["output_tokens"] as? Int ?? 0
                }
            }

            if messageCount > 0 && lastCacheRead > 0 { break }
        }

        let totalTokens = lastInputTokens + lastCacheCreation + lastCacheRead + lastOutputTokens
        let contextSize = 1_000_000
        let usedPct = contextSize > 0 ? min(totalTokens * 100 / contextSize, 100) : 0
        let isActive = activeIds.contains(sid)

        return RecentSession(
            id: sid,
            projectName: projectName,
            projectDir: cwd,
            entrypoint: entrypoint,
            startedAt: startedAt ?? lastActivity,
            lastActivity: lastActivity,
            contextUsedTokens: totalTokens,
            contextWindowSize: contextSize,
            usedPercentage: usedPct,
            remainingPercentage: max(100 - usedPct, 0),
            isActive: isActive,
            totalCost: totalCost,
            messageCount: messageCount
        )
    }

    private func extractProjectName(from dirName: String) -> String {
        // Convert "-Users-momenmush-projectname" to "projectname"
        // or "-Users-momenmush" to "~"
        let parts = dirName.split(separator: "-", omittingEmptySubsequences: false)
        // Skip leading empty + "Users" + username
        // Format: -Users-username-project or -Users-username
        if parts.count >= 4 {
            let projectParts = parts.dropFirst(3) // drop "", "Users", "username"
            let name = projectParts.joined(separator: "-")
            if name.isEmpty { return "~" }
            // Clean up worktree suffixes
            if let base = name.split(separator: "-", maxSplits: 1).first,
               name.contains("-claude-worktrees-") || name.contains(".claude-worktrees-") {
                return String(base)
            }
            return name
        }
        return dirName
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
