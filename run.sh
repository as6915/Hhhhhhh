#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="as6915"
REPO_NAME="p"
FILE_PATH="pn.sh"
BRANCH="main"

command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }

read -rsp "Enter GitHub token (repo scope): " GITHUB_TOKEN
echo

# تحقق من صلاحية التوكن
if ! curl -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" https://api.github.com/user | grep -q '"login"'; then
  echo "Invalid token or no access. Aborting." >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
chmod 700 "$TMPDIR"
OUT="$TMPDIR/$(basename "$FILE_PATH")"

cleanup(){ 
  unset GITHUB_TOKEN 2>/dev/null || true
  if command -v shred >/dev/null 2>&1; then
    shred -u -z "$OUT" 2>/dev/null || rm -f "$OUT"
  else
    rm -f "$OUT"
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}?ref=${BRANCH}"
HTTP_CODE=$(curl -sS -w "%{http_code}" -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$OUT" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download failed: HTTP $HTTP_CODE" >&2
  head -c 400 "$OUT" >&2 || true
  exit 1
fi

if head -n1 "$OUT" | grep -qE '^#!'; then
  chmod 700 "$OUT"
  unset GITHUB_TOKEN
  bash "$OUT"
else
  echo "Downloaded file doesn't look like a shell script. Preview:" >&2
  sed -n '1,120p' "$OUT" >&2
  exit 1
fi
