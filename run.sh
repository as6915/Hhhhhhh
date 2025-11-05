#!/usr/bin/env bash
set -euo pipefail

# --- إعداد الاسم الافتراضي للملف داخل مشاريعك ---
TARGET_FILENAME="pn.sh"

# --- يطلب التوكن منك ---
read -rsp "Enter GitHub token (with repo scope): " GITHUB_TOKEN
echo

# --- deps check ---
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

# --- تحقق من صلاحية التوكن وجلب اسم المستخدم ---
USER_LOGIN=$(curl -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  https://api.github.com/user | jq -r '.login // empty')
if [ -z "$USER_LOGIN" ]; then
  echo "Invalid token or unable to read user." >&2
  exit 1
fi

# --- البحث عن الملف في كل الريبو الخاصة بالمستخدم ---
QUERY="${TARGET_FILENAME} in:path user:${USER_LOGIN}"
SEARCH_JSON=$(curl -sS -G -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  --data-urlencode "q=${QUERY}" "https://api.github.com/search/code")
TOTAL=$(printf '%s' "$SEARCH_JSON" | jq -r '.total_count // 0')
if [ "$TOTAL" -eq 0 ]; then
  echo "No matches found for ${TARGET_FILENAME} in your repos." >&2
  exit 1
fi

# --- خذ أول نتيجة ---
REPO_FULL=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].repository.full_name')
FILE_PATH=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].path')
BRANCH=$(printf '%s' "$SEARCH_JSON" | jq -r '.items[0].repository.default_branch // "main"')

# --- حمل الملف مؤقتًا ---
TMPF=$(mktemp)
trap 'rm -f "$TMPF"' EXIT
API_URL="https://api.github.com/repos/${REPO_FULL}/contents/${FILE_PATH}?ref=${BRANCH}"
HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$TMPF" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download failed HTTP ${HTTP_CODE}" >&2
  head -c 200 "$TMPF" >&2 || true
  exit 1
fi

# --- نفّذ السكربت إذا بدا مثل ملف باش ---
if head -n1 "$TMPF" | grep -qE '^#!'; then
  chmod +x "$TMPF"
  unset GITHUB_TOKEN
  bash "$TMPF"
else
  echo "Downloaded file does not appear to be a shell script." >&2
  head -n50 "$TMPF" >&2
  exit 1
fi
