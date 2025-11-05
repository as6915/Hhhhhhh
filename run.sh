#!/usr/bin/env bash
set -euo pipefail

# ----- ثابتات (غيّر لو احتجت) -----
REPO_OWNER="as6915"
REPO_NAME="p"
FILE_PATH="pn.sh"
BRANCH="main"
# -----------------------------------

# deps
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

# أطلب التوكن بشكل آمن (لا يظهر على الشاشة)
read -rsp "Enter GitHub token (repo scope): " GITHUB_TOKEN
echo

# تحقق سريع من التوكن (يرجع اسم المستخدم لو صحيح)
USER_LOGIN=$(curl -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" https://api.github.com/user | jq -r '.login // empty')
if [ -z "$USER_LOGIN" ]; then
  echo "Invalid token or no access. Aborting." >&2
  exit 1
fi

# أنشئ مجلد مؤقت آمن
TMPDIR="$(mktemp -d)"
chmod 700 "$TMPDIR"
trap 'shopt -s nullglob; rm -rf "$TMPDIR"; unset GITHUB_TOKEN' EXIT

# حمل الملف مباشرة عبر GitHub API (Accept raw)
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}?ref=${BRANCH}"
OUT="$TMPDIR/$(basename "$FILE_PATH")"

HTTP_CODE=$(curl -w "%{http_code}" -sS -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" -o "$OUT" "$API_URL" || true)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download failed: HTTP ${HTTP_CODE}" >&2
  head -c 400 "$OUT" >&2 || true
  exit 1
fi

# تحقق أن المحتوى يبدو سكربت باش أو نص قابل للتنفيذ
if head -n1 "$OUT" | grep -qE '^#!'; then
  chmod 700 "$OUT"
  # امسح متغير التوكن من البيئة قبل التنفيذ قدر الإمكان
  unset GITHUB_TOKEN
  # نفّذ السكربت محلياً داخل نفس الجلسة (لن يُبقى أثر على repo أو history)
  bash "$OUT"
else
  echo "Downloaded file doesn't look like a shell script. Preview:" >&2
  sed -n '1,120p' "$OUT" >&2
  exit 1
fi
