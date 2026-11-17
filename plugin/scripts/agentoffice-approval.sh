#!/bin/bash
#
# AgentOffice approval hook
#
# Claude Code runs this on PermissionRequest, just before it asks the user to allow a tool.
# The terminal question still shows at once. While it is open, the AgentOffice app can
# answer it too: whichever answers first wins.
#
# 1. If the app is not open (no fresh .app-alive file), exit at once and change nothing.
# 2. Write <id>.request.json with what the tool will do, so the user can decide.
# 3. Wait for <id>.answer.json from the app, and pass its allow or deny to Claude Code.
# 4. Stop waiting when the question was answered in the terminal (a newer event for the
#    same agent shows up in the session log), when the app closes, or after a time limit.
#
# Privacy: the request holds the command or file path, because a user cannot approve
# safely without it. It is readable only by the user and removed as soon as the hook ends.
# Safety: every failure path exits 0 with no output, which leaves the terminal question as is.

set -u
umask 077

BASE_DIR="${AGENTOFFICE_DIR:-$HOME/Library/Application Support/AgentOffice}"
APPROVALS_DIR="$BASE_DIR/Approvals"
EVENTS_DIR="$BASE_DIR/Events"
WAIT_SECONDS="${AGENTOFFICE_APPROVAL_WAIT:-300}"
# A wait that is not a plain number would stop the script halfway, so fall back to the default.
case "$WAIT_SECONDS" in
  "" | *[!0-9]*) WAIT_SECONDS=300 ;;
esac
ALIVE_SECONDS=15

command -v jq >/dev/null 2>&1 || exit 0

app_is_open() {
  local alive="$APPROVALS_DIR/.app-alive" modified
  [ -f "$alive" ] || return 1
  modified="$(stat -f %m "$alive" 2>/dev/null)" || return 1
  [ $(( $(date +%s) - modified )) -le "$ALIVE_SECONDS" ]
}

app_is_open || exit 0

input="$(cat)" || exit 0

session="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
case "$session" in
  "" | *[!A-Za-z0-9-]*) exit 0 ;;
esac
agent="$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)"

id="$(uuidgen 2>/dev/null | tr 'A-Z' 'a-z')"
case "$id" in
  "" | *[!a-f0-9-]*) exit 0 ;;
esac

request="$APPROVALS_DIR/$id.request.json"
answer="$APPROVALS_DIR/$id.answer.json"
cleanup() { rm -f "$request" "$request.tmp" "$answer"; }
# The question file is removed however the script ends, so no question is left behind.
trap cleanup EXIT
trap 'exit 0' TERM INT HUP

project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_dir" ]; then
  project_dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
fi

# What the tool will do, in one line the user can read. Paths under home start with ~.
printf '%s' "$input" | jq -c \
  --arg id "$id" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg project "$(basename "${project_dir:-/}")" --arg home "$HOME" '
  def tidy: if startswith($home) then "~" + .[($home | length):] else . end;
  (.tool_input // {}) as $in
  | {
      id: $id,
      session: .session_id,
      agentId: .agent_id,
      project: $project,
      tool: .tool_name,
      summary: ((
        if $in.command then $in.command
        elif $in.file_path then ($in.file_path | tidy)
        elif $in.notebook_path then ($in.notebook_path | tidy)
        elif $in.url then $in.url
        elif $in.query then $in.query
        elif $in.pattern then $in.pattern
        else "" end) | tostring | .[0:1000]),
      ts: $ts
    }
  | with_entries(select(.value != null))
' > "$request.tmp" 2>/dev/null || { cleanup; exit 0; }
mv "$request.tmp" "$request" 2>/dev/null || { cleanup; exit 0; }

# Lines already in the session log. A newer line showing the same agent moved on (the tool ran,
# another tool started, the turn ended) means the question was answered in the terminal.
# Notification is not one of them: Claude Code sends it while the question is still open.
log="$EVENTS_DIR/$session.jsonl"
seen_lines=0
if [ -f "$log" ]; then
  seen_lines="$(wc -l < "$log" | tr -d ' ')"
fi

answered_elsewhere() {
  [ -f "$log" ] || return 1
  tail -n +"$((seen_lines + 1))" "$log" 2>/dev/null \
    | jq -e --arg agent "$agent" '
        select((.agentId // "") == $agent)
        | select(.event | IN("PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit", "SubagentStop", "SessionEnd"))' \
      >/dev/null 2>&1
}

deadline=$(( $(date +%s) + WAIT_SECONDS ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -f "$answer" ]; then
    decision="$(jq -r --arg id "$id" 'select(.id == $id) | .decision' "$answer" 2>/dev/null)"
    cleanup
    case "$decision" in
      allow)
        printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        ;;
      deny)
        printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied in AgentOffice."}}}'
        ;;
    esac
    exit 0
  fi
  if [ ! -f "$request" ] || ! app_is_open || answered_elsewhere; then
    break
  fi
  sleep 0.5
done

cleanup
exit 0
