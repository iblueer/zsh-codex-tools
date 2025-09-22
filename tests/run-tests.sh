#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")"/.. && pwd)"

for sh in zsh bash; do
  echo "=== testing $sh ==="
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  export CODEX_HOME="$tmp/.codex"
  mkdir -p "$CODEX_HOME/envs"
  if [ "$sh" = zsh ]; then
    export ZDOTDIR="$tmp"
  fi
  BIN="$ROOT/bin/codex-use.$([ "$sh" = zsh ] && echo zsh || echo bash)"

  _run() {
    $sh -c "set -e; source '$BIN'; $*"
  }

  echo "== list on empty =="
  out="$(_run 'codex-use list')"
  echo "$out" | grep -q '（空）' || { echo "FAIL: list should be empty"; exit 1; }

  echo "== new foo =="
  _run 'codex-use new foo' </dev/null || true
  test -f "$CODEX_HOME/envs/foo.env" || { echo "FAIL: foo.env not created"; exit 1; }

  echo "== edit bar (autocreate) =="
  rm -f "$CODEX_HOME/envs/bar.env"
  _run 'codex-use edit bar' </dev/null || true
  test -f "$CODEX_HOME/envs/bar.env" || { echo "FAIL: bar.env not created"; exit 1; }

  echo "== guard chatgpt name =="
  if _run 'codex-use new chatgpt-dev' 2>/dev/null; then
    echo "FAIL: chatgpt-dev should be rejected"; exit 1
  fi
  test ! -f "$CODEX_HOME/envs/chatgpt-dev.env" || { echo "FAIL: chatgpt-dev.env should not exist"; exit 1; }

  echo "== switch foo =="
  cat >>"$CODEX_HOME/envs/foo.env" <<'ENV'
export CODEX_MODEL="demo-model"
export CODEX_MODEL_PROVIDER="acme"
export CODEX_PREFERRED_AUTH_METHOD="apikey"
export CODEX_PROVIDER_NAME="Acme"
export CODEX_PROVIDER_BASE_URL="https://api.acme.test/v1"
export CODEX_PROVIDER_WIRE_API="rpc"
export OPENAI_API_KEY="demo-key"
ENV
  _run 'codex-use foo ; test "$CODEX_MODEL" = "demo-model"'
  grep -q 'model = "demo-model"' "$CODEX_HOME/config.toml" || { echo "FAIL: config not written"; exit 1; }
  grep -q 'model_provider = "acme"' "$CODEX_HOME/config.toml" || { echo "FAIL: provider not written"; exit 1; }
  grep -q 'base_url = "https://api.acme.test/v1"' "$CODEX_HOME/config.toml" || { echo "FAIL: base_url missing"; exit 1; }
  python3 - <<'PY'
import json, os
path = os.environ['CODEX_HOME'] + '/auth.json'
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
if data.get('OPENAI_API_KEY') != 'demo-key':
    raise SystemExit('FAIL: auth.json not updated')
PY

  echo "== switch chatgpt =="
  _run 'codex-use chatgpt'
  grep -q 'model_provider = "chatgpt"' "$CODEX_HOME/config.toml" || { echo "FAIL: chatgpt config missing"; exit 1; }
  python3 - <<'PY'
import json, os
path = os.environ['CODEX_HOME'] + '/auth.json'
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
if data.get('mode') != 'browser':
    raise SystemExit('FAIL: chatgpt auth marker missing')
PY

  echo "== del foo =="
  ( echo "yes" | _run 'codex-use del foo' )
  test ! -f "$CODEX_HOME/envs/foo.env" || { echo "FAIL: foo.env should be deleted"; exit 1; }

  rm -rf "$tmp"
  trap - EXIT
  echo
done

echo "== all pass =="
