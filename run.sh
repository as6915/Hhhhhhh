#!/usr/bin/env bash
set -euo pipefail

# طلب الرابط والتوكن محليًا (لا تبعته في الشات)
read -rp "GitHub file URL (e.g. https://github.com/owner/repo/blob/branch/path/to/file): " FILE_URL
read -rsp "Enter GitHub token (repo scope): " GITHUB_TOKEN
echo

# deps
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

# استخراج owner/repo/branch/path من عدة صيغ شائعة
if printf '%s' "$FILE_URL" | grep -qE '^https?://raw\.githubusercontent\.com/'; then
  # raw.githubusercontent.com/OWNER/REPO/BRANCH/PATH
  rest=${FILE_URL#*raw.githubusercontent.com/}
  OWNER=$(printf '%s' "$rest" | cut -d'/' -f1)
  REPO=$(printf '%s' "$rest" | cut -d'/' -f2)
  BRANCH=$(printf '%s' "$rest" | cut -d'/' -f3)
  FILE_PATH=$(printf '%s' "$rest" | cut -d'/' -f4-)
elif printf '%s' "$FILE_URL" | grep -qE '^https?://github\.com/.+/blob/'; then
  # github.com/OWNER/REPO/blob/BRANCH/PATH
  rest=${FILE_URL#*github.com/}
  OWNER=$(printf '%s' "$rest" | cut -d'/' -f1)
  REPO=$(printf '%s' "$rest" | cut -d'/' -f2)
  # ensure 'blob' present
  BLOB=$(printf '%s' "$rest" | cut -d'/' -f3)
  if [ "$BLOB" != "blob" ]; then
    echo "URL doesn't contain /blob/. Aborting." >&2
    exit 1
  fi
  BRANCH=$(printf '%s' "$rest" | cut -d'/' -f4)
  FILE_PATH=$(printf '%s' "$rest" | cut -d'/' -f5-)
else
  echo "Unsupported URL format." >&2
  exit 1
fi

: "${OWNER:?}"
: "${REPO:?}"
: "${BRANCH:?}"
: "${FILE_PATH:?}"

TMPDIR=$(mktemp -d)
chmod 700 "$TMPDIR"
OUT="$TMPDIR/$(basename "$FILE_PATH")"
trap 'rm -rf "$TMPDIR"; unset GITHUB_TOKEN' EXIT

API_URL="https://api.github.com/repos/${OWNER}/${REPO}/contents/${FILE_PATH}?ref=${BRANCH}"

HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$OUT" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download failed: HTTP $HTTP_CODE" >&2
  head -c 400 "$OUT" >&2 || true
  exit 1
fi

# تأكد أن الملف سكربت شيل ثم شغّله محليًا
if head -n1 "$OUT" | grep -qE '^#!'; then
  chmod 700 "$OUT"
  unset GITHUB_TOKEN
  bash "$OUT"
else
  echo "Downloaded file doesn't look like a shell script. Preview:" >&2
  sed -n '1,120p' "$OUT" >&2
  exit 1
fi
