#!/bin/bash
#
# AgentOffice event hook
#
# Claude Code runs this script on hook events and passes the event as JSON on stdin.
# The script appends a minimal summary of each event to a per-session JSON Lines file,
# which the AgentOffice Mac app reads to animate the office.
#
# Privacy: only whitelisted fields are recorded. Prompts, tool inputs, command text,
# file contents and full paths are never written. The project is stored as its folder name,
# plus the folder's volume and file numbers, so the app can follow a rename or notice a deletion
# without knowing where the folder is.
#
# Safety: the script must never interrupt Claude Code, so every failure path exits 0.

set -u
umask 077

EVENTS_DIR="${AGENTOFFICE_EVENTS_DIR:-$HOME/Library/Application Support/AgentOffice/Events}"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)" || exit 0
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Use the folder the session started in, so moving into a subfolder does not change the project.
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_dir" ]; then
  project_dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)" || project_dir=""
fi

# The folder's volume and file numbers stay the same when the folder is renamed.
project_device=""
project_inode=""
if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
  folder_id="$(stat -f '%d %i' "$project_dir" 2>/dev/null)" || folder_id=""
  case "$folder_id" in
    *[!0-9\ ]* | "") ;;
    *) project_device="${folder_id%% *}"; project_inode="${folder_id##* }" ;;
  esac
fi

line="$(printf '%s' "$input" | jq -c --arg ts "$timestamp" --arg projectDir "$project_dir" \
  --arg device "$project_device" --arg inode "$project_inode" '
  {
    ts: $ts,
    event: .hook_event_name,
    session: .session_id,
    project: ((($projectDir | select(. != "")) // .cwd // "") | rtrimstr("/") | split("/") | last),
    tool: .tool_name,
    agentId: .agent_id,
    agentType: .agent_type,
    notification: .notification_type,
    source: .source,
    reason: .reason,
    projectDevice: (if $device == "" then null else ($device | tonumber) end),
    projectInode: (if $inode == "" then null else ($inode | tonumber) end)
  }
  | with_entries(select(.value != null and .value != ""))
' 2>/dev/null)" || exit 0

session="$(printf '%s' "$line" | jq -r '.session // empty' 2>/dev/null)"

# The session ID becomes a file name, so allow only safe characters.
case "$session" in
  "" | *[!A-Za-z0-9-]*) exit 0 ;;
esac

mkdir -p "$EVENTS_DIR" 2>/dev/null || exit 0
printf '%s\n' "$line" >> "$EVENTS_DIR/$session.jsonl" 2>/dev/null

exit 0
