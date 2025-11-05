#!/usr/bin/env bash
set -euo pipefail

# --- إعداد المتغيرات ---
REPO_OWNER="as6915"
REPO_NAME="p"
FILE_PATH="pn.sh"
BRANCH="main"

# --- يطلب التوكن منك ---
read -rsp "Enter GitHub token (with repo scope): " GITHUB_TOKEN
echo

# --- deps check ---
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }

# --- تحميل الملف عبر GitHub API ---
TMPF=$(mktemp)
trap 'rm -f "$TMPF"' EXIT
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}?ref=${BRANCH}"
HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$TMPF" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download failed HTTP ${HTTP_CODE}" >&2
  head -c 200 "$TMPF" >&2 || true
  exit 1
fi

# --- تنفيذ الملف إذا بدا مثل سكربت باش ---
if head -n1 "$TMPF" | grep -qE '^#!'; then
  chmod +x "$TMPF"
  unset GITHUB_TOKEN
  bash "$TMPF"
else
  echo "Downloaded file does not appear to be a shell script." >&2
  head -n50 "$TMPF" >&2
  exit 1
fi
