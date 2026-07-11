#!/usr/bin/env bash
set -euo pipefail

source_file="${1:-mocklib.sh}"

grep -q 'MOCKLIB_API_URL:-https://mockfactory.io/api/v1' "$source_file"
grep -q 'X-API-Key: ${_MOCKLIB_KEY}' "$source_file"
if grep -q 'Authorization: Bearer ${_MOCKLIB_KEY}' "$source_file"; then
  echo "API key still uses bearer authentication" >&2
  exit 1
fi

echo "Shell client contract passed"
