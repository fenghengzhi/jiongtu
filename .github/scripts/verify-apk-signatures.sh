#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )); then
  echo "Usage: $0 <certificate-sha256-file> <apk> [apk ...]" >&2
  exit 2
fi

: "${APKSIGNER:?Set APKSIGNER to the Android build-tools apksigner executable}"
expected=$(tr -d '[:space:]:' < "$1" | tr '[:upper:]' '[:lower:]')
shift
if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'Expected certificate SHA-256 must contain exactly 64 hexadecimal digits.' >&2
  exit 1
fi

for apk in "$@"; do
  report=$("$APKSIGNER" verify --verbose --print-certs "$apk")
  actual=$(awk -F ': ' '/^Signer #[0-9]+ certificate SHA-256 digest:/ { print tolower($2) }' <<< "$report")
  # An empty result or multiple signer certificates also fails this comparison.
  if [[ "$actual" != "$expected" ]]; then
    echo "Unexpected signing certificate: $apk" >&2
    exit 1
  fi
  printf '%s: verified certificate SHA-256 %s\n' "$(basename "$apk")" "$actual"
done
