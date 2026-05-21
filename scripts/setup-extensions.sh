#!/usr/bin/env bash
set -euo pipefail

VSCODE_VERSION="${VSCODE_VERSION:-1.110.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTENSIONS_DIR="$REPO_ROOT/extensions"

if [[ -d "$EXTENSIONS_DIR" && "$(ls -A "$EXTENSIONS_DIR" 2>/dev/null | wc -l)" -gt 10 ]]; then
  echo "extensions/ already populated ($(ls "$EXTENSIONS_DIR" | wc -l | tr -d ' ') entries) — skipping."
  exit 0
fi

mkdir -p "$EXTENSIONS_DIR"

VSCODE_CANDIDATES=(
  "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions"
  "/Applications/Cursor.app/Contents/Resources/app/extensions"
  "/usr/share/code/resources/app/extensions"
  "/usr/lib/code/extensions"
  "/opt/visual-studio-code/resources/app/extensions"
  "$HOME/.vscode/extensions"
)

for candidate in "${VSCODE_CANDIDATES[@]}"; do
  if [[ -d "$candidate" && "$(ls -A "$candidate" 2>/dev/null | wc -l)" -gt 10 ]]; then
    echo "Found VSCode extensions at: $candidate"
    echo "Copying built-in extensions..."
    cp -r "$candidate"/. "$EXTENSIONS_DIR/"
    echo "Copied $(ls "$EXTENSIONS_DIR" | wc -l | tr -d ' ') extensions."
    exit 0
  fi
done

echo "No local VSCode installation found. Downloading from GitHub..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="$TMP_DIR/vscode.tar.gz"
TAG_CANDIDATES=("$VSCODE_VERSION")
if [[ "$VSCODE_VERSION" =~ ^([0-9]+)\.([0-9]+)\.0$ ]]; then
  TAG_CANDIDATES+=("${BASH_REMATCH[1]}.${BASH_REMATCH[2]}")
fi

downloaded=0
archive_root=""

if [[ -n "${VSCODE_SOURCE_URL:-}" ]]; then
  echo "Downloading VS Code source archive from: $VSCODE_SOURCE_URL"
  if curl --fail --location --retry 3 --retry-all-errors --connect-timeout 20 --progress-bar "$VSCODE_SOURCE_URL" -o "$ARCHIVE"; then
    archive_root="$(tar -tzf "$ARCHIVE" 2>/dev/null | head -n 1 | cut -d / -f 1)"
    if [[ -n "$archive_root" ]] && tar -tzf "$ARCHIVE" "$archive_root/extensions" >/dev/null 2>&1; then
      downloaded=1
    else
      echo "Downloaded file is not a valid VS Code source archive." >&2
    fi
  fi
fi

if [[ "$downloaded" -ne 1 ]]; then
  for tag in "${TAG_CANDIDATES[@]}"; do
    url="https://codeload.github.com/microsoft/vscode/tar.gz/refs/tags/${tag}"

    echo "Downloading VS Code source archive from: $url"
    if curl --fail --location --retry 3 --retry-all-errors --connect-timeout 20 --progress-bar "$url" -o "$ARCHIVE"; then
      archive_root="$(tar -tzf "$ARCHIVE" 2>/dev/null | head -n 1 | cut -d / -f 1)"
      if [[ -n "$archive_root" ]] && tar -tzf "$ARCHIVE" "$archive_root/extensions" >/dev/null 2>&1; then
        downloaded=1
        break
      fi

      echo "Downloaded file is not a valid VS Code source archive for tag ${tag}." >&2
    fi
  done
fi

if [[ "$downloaded" -ne 1 ]]; then
  for tag in "${TAG_CANDIDATES[@]}"; do
    url="https://github.com/microsoft/vscode/archive/refs/tags/${tag}.tar.gz"

    echo "Downloading VS Code source archive from: $url"
    if curl --fail --location --retry 3 --retry-all-errors --connect-timeout 20 --progress-bar "$url" -o "$ARCHIVE"; then
      archive_root="$(tar -tzf "$ARCHIVE" 2>/dev/null | head -n 1 | cut -d / -f 1)"
      if [[ -n "$archive_root" ]] && tar -tzf "$ARCHIVE" "$archive_root/extensions" >/dev/null 2>&1; then
        downloaded=1
        break
      fi

      echo "Downloaded file is not a valid VS Code source archive for tag ${tag}." >&2
    fi
  done
fi

if [[ "$downloaded" -ne 1 ]]; then
  echo "Could not download VS Code built-in extensions for ${VSCODE_VERSION}." >&2
  echo "Set VSCODE_VERSION to a valid microsoft/vscode tag or VSCODE_SOURCE_URL to a tar.gz archive." >&2
  exit 1
fi

echo "Extracting extensions..."
tar -xzf "$ARCHIVE" -C "$TMP_DIR" "$archive_root/extensions"
cp -r "$TMP_DIR/$archive_root/extensions/." "$EXTENSIONS_DIR/"

echo "Done — $(ls "$EXTENSIONS_DIR" | wc -l | tr -d ' ') extensions installed."
