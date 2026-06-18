#!/usr/bin/env bash
# UserPromptSubmit hook. Nudges (via a user-visible systemMessage) when the user
# submits a *similar* prompt THRESHOLD times, suggesting a skill/command/alias.
#
# Similarity = Jaccard over character n-gram sets, computed in embedded python3 so
# it is language-agnostic: handles Japanese (no whitespace / tokenizer needed) and
# English alike. Self-contained (no sibling .py); the hook JSON is captured from
# stdin and handed to python via env (the heredoc is python's program on stdin).
# Nudge-only: never blocks, always exits 0. Fires only when a cluster *first*
# reaches THRESHOLD, and never twice for the same fuzzy cluster.
#
# Tunables (env, all optional):
#   PROMPT_NGRAM_N=2  PROMPT_REPEAT_THRESHOLD=3  PROMPT_SIM_THRESHOLD=0.5
#   PROMPT_MIN_NGRAMS=5  PROMPT_SIG_LOG=<path>
set -u

input="$(cat)"
HOOK_JSON="$input" SIG_LOG="${PROMPT_SIG_LOG:-$HOME/.claude/.prompt-signatures.log}" python3 <<'PY'
import os, json, sys

N = int(os.environ.get("PROMPT_NGRAM_N", "2"))
THRESHOLD = int(os.environ.get("PROMPT_REPEAT_THRESHOLD", "3"))
SIM = float(os.environ.get("PROMPT_SIM_THRESHOLD", "0.5"))
MIN_NGRAMS = int(os.environ.get("PROMPT_MIN_NGRAMS", "5"))

def normalize(s): return "".join(s.lower().split())
def ngrams(s): return {s[i:i+N] for i in range(len(s)-N+1)} if len(s) >= N else set()
def jaccard(a, b): return (len(a & b) / len(a | b)) if a and b else 0.0

def read_lines(p):
    # errors="replace": a single corrupt (non-UTF-8) line must never raise and
    # brick the hook. Without this a bad line makes every later run crash on read
    # (before the append), silently freezing the log forever.
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return [ln.rstrip("\n") for ln in f if ln.strip()]
    except OSError:
        return []

try:
    data = json.loads(os.environ.get("HOOK_JSON", "") or "{}")
except Exception:
    sys.exit(0)

prompt = (data.get("prompt") or "").strip()
# Skip empties and slash-commands (already a shortcut).
if not prompt or prompt.startswith("/"):
    sys.exit(0)

norm = normalize(prompt)
grams = ngrams(norm)
if len(grams) < MIN_NGRAMS:  # too short to act on ("ok go", etc.)
    sys.exit(0)

log = os.environ["SIG_LOG"]
nudged_log = log + ".nudged"

past = read_lines(log)
similar_past = sum(1 for p in past if jaccard(grams, ngrams(p)) >= SIM)

os.makedirs(os.path.dirname(log) or ".", exist_ok=True)
with open(log, "a", encoding="utf-8") as f:
    f.write(norm + "\n")

# Cluster size includes the current submission. Fire once, on first crossing, and
# never twice for the same fuzzy cluster (so a growing cluster doesn't nag).
if similar_past + 1 == THRESHOLD:
    already = any(jaccard(grams, ngrams(p)) >= SIM for p in read_lines(nudged_log))
    if not already:
        msg = (f"似たプロンプトを{THRESHOLD}回入力しています。"
               "スキル/スラッシュコマンド化やエイリアスで効率化できるかもしれません"
               "（/jiska:suggest-harness で具体案を生成できます）。")
        print(json.dumps({"systemMessage": msg}, ensure_ascii=False))
        with open(nudged_log, "a", encoding="utf-8") as f:
            f.write(norm + "\n")
PY
exit 0
