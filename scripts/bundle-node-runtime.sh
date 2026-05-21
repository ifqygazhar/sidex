#!/usr/bin/env bash
set -euo pipefail

target="${1:-aarch64-apple-darwin}"
major="${NODE_RUNTIME_MAJOR:-22}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/src-tauri/node"
base_url="https://nodejs.org/dist/latest-v${major}.x"

verify_sha256() {
  local file="$1"
  local expected="$2"

  if command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$file" | shasum -a 256 -c -
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
  else
    echo "No SHA-256 verification tool found" >&2
    exit 1
  fi
}

download_node() {
  local sidex_arch="$1"
  local node_arch="$2"
  local shasums archive expected tmp extracted target_dir

  echo "Resolving Node.js latest-v${major}.x for darwin-${node_arch}"
  shasums="$(curl -fsSL "$base_url/SHASUMS256.txt")"
  archive="$(
    printf '%s\n' "$shasums" \
      | awk '{ print $2 }' \
      | grep -E "^node-v[0-9]+\\.[0-9]+\\.[0-9]+-darwin-${node_arch}\\.tar\\.gz$" \
      | head -n 1
  )"

  if [[ -z "$archive" ]]; then
    echo "Could not find Node.js archive for darwin-${node_arch}" >&2
    exit 1
  fi

  expected="$(
    printf '%s\n' "$shasums" \
      | awk -v archive="$archive" '$2 == archive { print $1; exit }'
  )"

  if [[ -z "$expected" ]]; then
    echo "Could not find SHA-256 checksum for $archive" >&2
    exit 1
  fi

  tmp="$(mktemp -d)"
  target_dir="$out_dir/darwin-${sidex_arch}"
  curl -fsSL "$base_url/$archive" -o "$tmp/$archive"
  verify_sha256 "$tmp/$archive" "$expected"
  tar -xzf "$tmp/$archive" -C "$tmp"
  extracted="$tmp/${archive%.tar.gz}"

  rm -rf "$target_dir"
  mkdir -p "$target_dir/bin"
  cp "$extracted/bin/node" "$target_dir/bin/node"
  chmod +x "$target_dir/bin/node"
  "$target_dir/bin/node" --version

  rm -rf "$tmp"
}

rm -rf "$out_dir"
mkdir -p "$out_dir"

case "$target" in
  aarch64-apple-darwin)
    download_node arm64 arm64
    ;;
  x86_64-apple-darwin)
    download_node x64 x64
    ;;
  universal-apple-darwin)
    download_node arm64 arm64
    download_node x64 x64
    ;;
  *)
    echo "No bundled Node runtime configured for target '$target'"
    ;;
esac
