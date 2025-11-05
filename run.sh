#!/usr/bin/env bash
set -euo pipefail

: "${REPO_OWNER:=as6915}"
: "${REPO_NAME:=p}"
: "${FILE_PATH:=pn.sh}"
: "${BRANCH:=main}"

# احصل على التوكن من متغير البيئة أو اطلبه
if [ -z "${GITHUB_TOKEN-}" ]; then
  read -rsp "Enter GitHub token: " GITHUB_TOKEN
  echo
fi

API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}?ref=${BRANCH}"

# حمل الملف مؤقتاً
tmpf="$(mktemp)"
trap 'rm -f "$tmpf"' EXIT

http_code=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$tmpf" "$API_URL" || true)

if [ "$http_code" != "200" ]; then
  echo "Download failed: HTTP $http_code" >&2
  head -c 200 "$tmpf" >&2
  exit 1
fi

# نفذ الملف فقط لو يبدو سكربت باش
if head -n1 "$tmpf" | grep -qE '^#!'; then
  chmod +x "$tmpf"
  unset GITHUB_TOKEN
  bash "$tmpf"
else
  echo "Downloaded file doesn't look like a shell script. Preview:" >&2
  head -n50 "$tmpf" >&2
  exit 1
fi
