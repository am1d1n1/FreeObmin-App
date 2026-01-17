#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo >&2 "error: $*"
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command '$1' is missing"
  fi
}

trim() {
  local input
  input="$(cat)"
  if [[ -z "$input" ]]; then
    echo ""
    return
  fi
  echo "$input" | tr -d '\r' | awk '{$1=$1};1'
}

require_command flutter
require_command gh
require_command git

if [[ ! -f ".env" ]]; then
  fail ".env file not found; create one or copy .env.example"
fi

get_env_value() {
  local key="$1"
  local raw
  raw="$(grep -E "^${key}=" .env | tail -n1 || true)"
  if [[ -z "$raw" ]]; then
    echo ""
    return
  fi
  echo "$raw" | cut -d= -f2- | trim
}

OWNER="$(get_env_value 'GITHUB_UPDATE_OWNER')"
REPO="$(get_env_value 'GITHUB_UPDATE_REPO')"
REPO_ARG="--repo ${OWNER}/${REPO}"

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  fail "GITHUB_UPDATE_OWNER and GITHUB_UPDATE_REPO must be set in .env"
fi

VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -n1 || true)"
if [[ -z "$VERSION_LINE" ]]; then
  fail "failed to read the version line from pubspec.yaml"
fi

VERSION="$(echo "$VERSION_LINE" | awk '{print $2}' | cut -d+ -f1)"
if [[ -z "$VERSION" ]]; then
  fail "version in pubspec.yaml is empty"
fi

TAG="v$VERSION"

if [[ -n $(git status --porcelain) ]]; then
  fail "working tree is dirty; commit or stash changes before releasing"
fi

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
RELEASE_NOTES="${RELEASE_NOTES:-Automated build $TAG ($(date -u +"%Y-%m-%d %H:%M UTC"))}"

echo "building release $TAG"
flutter pub get
flutter build apk --release

if [[ ! -f "$APK_PATH" ]]; then
  fail "APK not found at $APK_PATH"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  fail "tag $TAG already exists; bump the version in pubspec.yaml"
fi

git tag "$TAG" -m "Release $TAG"
git push origin "$TAG"

if gh release view "$TAG" $REPO_ARG >/dev/null 2>&1; then
  echo "updating existing release $TAG"
  gh release upload "$TAG" $REPO_ARG "$APK_PATH" --clobber
else
  echo "creating release $TAG"
  gh release create "$TAG" $REPO_ARG "$APK_PATH" \
    --title "$TAG" \
    --notes "$RELEASE_NOTES" \
    --target "$(git rev-parse HEAD)"
fi

echo "release $TAG published to ${OWNER}/${REPO}"
