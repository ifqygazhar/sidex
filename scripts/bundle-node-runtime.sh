#!/usr/bin/env bash
set -euo pipefail

target="${1:-aarch64-apple-darwin}"
major="${NODE_RUNTIME_MAJOR:-22}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$root/src-tauri/node"
base_url="https://nodejs.org/dist/latest-v${major}.x"

download_node() {
  local sidex_arch="$1"
  local node_arch="$2"
  local shasums archive tmp extracted target_dir

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

  tmp="$(mktemp -d)"
  target_dir="$out_dir/darwin-${sidex_arch}"
  curl -fsSL "$base_url/$archive" -o "$tmp/$archive"
  tar -xzf "$tmp/$archive" -C "$tmp"
  extracted="$tmp/${archive%.tar.gz}"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -R "$extracted/bin" "$target_dir/"
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
