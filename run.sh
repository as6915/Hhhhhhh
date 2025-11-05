#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="as6915"
REPO_NAME="p"
FILE_PATH="pn.sh"
BRANCH="main"

command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }

read -rsp "Enter GitHub token (repo scope): " GITHUB_TOKEN
echo

TMPDIR="$(mktemp -d)"
chmod 700 "$TMPDIR"
OUT="$TMPDIR/$(basename "$FILE_PATH")"
trap 'rm -rf "$TMPDIR"; unset GITHUB_TOKEN' EXIT

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}?ref=${BRANCH}"

HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$OUT" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  head -c 400 "$OUT" >&2 || true
  exit 1
fi

if head -n1 "$OUT" | grep -qE '^#!'; then
  chmod 700 "$OUT"
  unset GITHUB_TOKEN
  bash "$OUT"
else
  sed -n '1,120p' "$OUT" >&2
  exit 1
fi
