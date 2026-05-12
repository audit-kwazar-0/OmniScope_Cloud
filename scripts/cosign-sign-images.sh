#!/usr/bin/env bash
set -euo pipefail

if ! command -v cosign >/dev/null 2>&1; then
  echo "cosign is required but not installed." >&2
  exit 1
fi

if [[ -z "${COSIGN_PRIVATE_KEY_PATH:-}" ]]; then
  echo "Set COSIGN_PRIVATE_KEY_PATH to sign images." >&2
  exit 1
fi

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 <image> [image...]" >&2
  exit 1
fi

for image in "$@"; do
  echo "Signing image: $image"
  cosign sign --yes --key "$COSIGN_PRIVATE_KEY_PATH" "$image"
done
