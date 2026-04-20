#!/usr/bin/env bash
# Claude Code PostToolUse hook: after the agent finishes running an approved
# tool, flip a notification-kind entry back to running — the permission
# prompt has been answered but the agent is still mid-turn, so the row
# should stay visible (with the play icon) until Stop fires. Running/stop
# entries are left alone.

set -eu

STATE_FILE="${HOME}/.claude/attention.json"
[ ! -f "${STATE_FILE}" ] && exit 0

payload="$(cat)"

# Debug trace — remove once the hook wiring is stable.
printf '%s clearnotif pid=%s payload=%s\n' "$(date +%s)" "$$" "${payload}" >> "${HOME}/.claude/attention-debug.log"

session_id="$(printf '%s' "${payload}" | jq -r '.session_id // empty')"
[ -z "${session_id}" ] && exit 0

# Require the notification entry to be at least this many seconds old before
# flipping back. Without it, PostToolUse can fire within milliseconds of the
# Notification write — the extension's file watcher coalesces both events
# and never observes the notification at all.
min_age_seconds=2
min_ts="$(( $(date +%s) - min_age_seconds ))"
now_ts="$(date +%s)"

updated="$(jq --arg sid "${session_id}" --argjson min_ts "${min_ts}" --argjson now "${now_ts}" '
  if .[$sid]?
     and .[$sid].kind == "notification"
     and ((.[$sid].ts // 0) <= $min_ts)
  then .[$sid] |= (
    .kind = "running"
    | .last_text = (.running_text // "")
    | .ts = $now
    | del(.running_text)
  )
  else .
  end
' "${STATE_FILE}" 2>/dev/null || printf '{}')"

tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
printf '%s\n' "${updated}" > "${tmp}"
mv "${tmp}" "${STATE_FILE}"
