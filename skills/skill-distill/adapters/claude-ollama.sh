#!/usr/bin/env bash
# Claude Code driven by an open model behind Ollama's Anthropic-compatible API. MODEL is the Ollama
# name, e.g. deepseek-v4.1-flash:cloud. The student keeps the reference's harness (same CLI, permission
# mode and settings) and only the model changes.
#
#   OLLAMA_URL                 default http://127.0.0.1:11434
#   CLAUDE_STUDENT_SETTINGS    settings.json to run under (permissions, hooks); default none
#   CLAUDE_STUDENT_SKILLS      skills folder the student may use; default none
#   CLAUDE_STUDENT_MODE        --permission-mode; default acceptEdits
#
# The student gets its own CLAUDE_CONFIG_DIR inside the trial, so it never sees the user's CLAUDE.md,
# plugins or stored login, and Anthropic credentials are unset so none is sent to the Ollama server.
set -uo pipefail
cd "$WORKSPACE" || exit 2
home="$TRACE_DIR/claude-home"
mkdir -p "$home"
[ -n "${CLAUDE_STUDENT_SETTINGS:-}" ] && cp "$CLAUDE_STUDENT_SETTINGS" "$home/settings.json"
[ -n "${CLAUDE_STUDENT_SKILLS:-}" ] && ln -sfn "$CLAUDE_STUDENT_SKILLS" "$home/skills"
unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
export CLAUDE_CONFIG_DIR="$home"
export ANTHROPIC_BASE_URL="${OLLAMA_URL:-http://127.0.0.1:11434}" ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL" ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL" CLAUDE_CODE_SUBAGENT_MODEL="$MODEL"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
claude -p --permission-mode "${CLAUDE_STUDENT_MODE:-acceptEdits}" --output-format stream-json --verbose \
    --model "$MODEL" ${STUDENT_ARGS:-} "$(cat "$PROMPT_FILE")" \
  | tee "$TRACE_DIR/session.jsonl" \
  | python3 -c 'import sys,json
for l in sys.stdin:
    try: o=json.loads(l)
    except Exception: continue
    m=o.get("message") if isinstance(o,dict) else None
    c=m.get("content") if isinstance(m,dict) else None
    for b in c if isinstance(c,list) else []:
        if isinstance(b,dict) and b.get("type")=="text": print("agent:",b["text"][:400],flush=True)
        elif isinstance(b,dict) and b.get("type")=="tool_use": print("tool:",b.get("name"),json.dumps(b.get("input"))[:200],flush=True)'
exit ${PIPESTATUS[0]}
