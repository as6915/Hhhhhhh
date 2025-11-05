#!/usr/bin/env bash
set -euo pipefail

TARGET_DEFAULT="pn.sh"

read -rsp "Enter GitHub token: " GITHUB_TOKEN
echo
read -rp "Target filename (default: ${TARGET_DEFAULT}): " TARGET_FILENAME
TARGET_FILENAME="${TARGET_FILENAME:-$TARGET_DEFAULT}"

# deps check
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

# whoami
USER_LOGIN=$(curl -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" https://api.github.com/user | jq -r '.login // empty')
if [ -z "$USER_LOGIN" ]; then
  echo "Invalid token or unable to read user." >&2
  exit 1
fi

# search code in user's repos
QUERY="${TARGET_FILENAME} in:path user:${USER_LOGIN}"
SEARCH_JSON=$(curl -sS -G -H "Authorization: Bearer ${GITHUB_TOKEN}" --data-urlencode "q=${QUERY}" "https://api.github.com/search/code")
TOTAL=$(printf '%s' "$SEARCH_JSON" | jq -r '.total_count // 0')
if [ "$TOTAL" -eq 0 ]; then
  echo "No matches found for ${TARGET_FILENAME} in user ${USER_LOGIN}." >&2
  exit 1
fi

# take first match
REPO_FULL=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].repository.full_name')
FILE_PATH=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].path')
DEFAULT_BRANCH=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].repository.default_branch // "main"')

# download raw content
API_URL="https://api.github.com/repos/${REPO_FULL}/contents/${FILE_PATH}?ref=${DEFAULT_BRANCH}"
TMPF=$(mktemp)
trap 'rm -f "$TMPF"' EXIT

HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3.raw" -o "$TMPF" "$API_URL" || true)
if [ "$HTTP_CODE" != "200" ]; then
  head -c 400 "$TMPF" >&2 || true
  echo >&2
  echo "Download failed HTTP ${HTTP_CODE}" >&2
  exit 1
fi

# sanity: must look like shell script (shebang) or be executable text
if head -n1 "$TMPF" | grep -qE '^#!'; then
  chmod +x "$TMPF"
  unset GITHUB_TOKEN
  bash "$TMPF"
else
  echo "Downloaded file does not appear to be a shell script. Preview:" >&2
  sed -n '1,120p' "$TMPF" >&2
  exit 1
fi
