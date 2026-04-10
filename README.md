# ClaudeContextBar

A macOS menu bar app that monitors your Claude Code session context windows in real time.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## What it does

A small horizontal bar sits in your menu bar showing how much context window capacity remains in your current Claude Code session. Click it to see every session from the last 24 hours.

### Menu Bar Icon

A compact bar filled with Claude's terracotta color, showing `session` on the left and remaining `%` on the right. The fill drains as context is consumed, just like a battery.

### Popover (click to open)

- **All sessions from the last 24 hours** with individual context bars
- **Active session indicator** with live token counts and cost
- **Token breakdown** (input, output, cache)
- **Rate limits** (5-hour and 7-day) with reset timers
- **Project name, entrypoint** (CLI/Desktop), and time since last activity

## Install

### Download

1. Grab `ClaudeContextBar-v1.0.0.zip` from the [latest release](https://github.com/MomenMushtaha/ClaudeContextBar/releases/latest)
2. Unzip and move `ClaudeContextBar.app` to `/Applications/`
3. Open it once from Applications

### Auto-launch setup

To have it start automatically when a Claude Code session opens:

```bash
# Copy the LaunchAgent plist (update the WatchPaths inside if your home dir differs)
cp com.claude.contextbar.watcher.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.claude.contextbar.watcher.plist
```

The app auto-quits 60 seconds after the last session ends.

### Build from source

```bash
git clone https://github.com/MomenMushtaha/ClaudeContextBar.git
cd ClaudeContextBar
bash build.sh
```

The build script compiles, bundles, installs to `/Applications/`, and sets up the LaunchAgent.

## How it works

- Reads `~/.claude/sessions/` to discover active Claude Code processes
- Reads `~/.claude/usage-live.json` for real-time context window, rate limit, and cost data
- Scans transcript files in `~/.claude/projects/` for historical session context usage
- Refreshes every 3 seconds (live data) and 10 seconds (transcript scan)
- LaunchAgent watches `~/.claude/sessions/` and launches the app when a new session file appears

## Uninstall

```bash
launchctl bootout gui/$(id -u)/com.claude.contextbar.watcher
rm ~/Library/LaunchAgents/com.claude.contextbar.watcher.plist
rm -rf /Applications/ClaudeContextBar.app
```

## Requirements

- macOS 13.0 or later
- Claude Code installed (CLI or Desktop)
