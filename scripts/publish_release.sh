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

BUMP_VERSION="${BUMP_VERSION:-minor}"

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

read_version() {
  local line
  line="$(grep -E '^version:' pubspec.yaml | head -n1 || true)"
  if [[ -z "$line" ]]; then
    fail "failed to read the version line from pubspec.yaml"
  fi
  echo "$line" | awk '{print $2}'
}

write_version() {
  local new_version="$1"
  awk -v v="$new_version" '
    BEGIN { updated=0 }
    /^version:/ { print "version: " v; updated=1; next }
    { print }
    END { if (!updated) exit 1 }
  ' pubspec.yaml > pubspec.yaml.tmp && mv -f pubspec.yaml.tmp pubspec.yaml
}

bump_minor() {
  local version_raw="$1"
  local base="${version_raw%%+*}"
  local build="0"
  if [[ "$version_raw" == *"+"* ]]; then
    build="${version_raw#*+}"
  fi
  IFS='.' read -r major minor patch <<<"$base"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"
  minor=$((minor + 1))
  patch=0
  build=$((build + 1))
  echo "${major}.${minor}.${patch}+${build}"
}

if [[ -n $(git status --porcelain) ]]; then
  fail "working tree is dirty; commit or stash changes before releasing"
fi

if [[ "$BUMP_VERSION" == "minor" ]]; then
  CURRENT_VERSION="$(read_version)"
  NEW_VERSION="$(bump_minor "$CURRENT_VERSION")"
  echo "bumping version: ${CURRENT_VERSION} -> ${NEW_VERSION}"
  write_version "$NEW_VERSION"
  flutter pub get
  if [[ -n $(git status --porcelain) ]]; then
    git add pubspec.yaml pubspec.lock
    git commit -m "chore: bump version to v${NEW_VERSION}"
  fi
elif [[ "$BUMP_VERSION" != "none" ]]; then
  fail "unsupported BUMP_VERSION value: $BUMP_VERSION"
fi

VERSION_RAW="$(read_version)"
VERSION="$(echo "$VERSION_RAW" | cut -d+ -f1)"
if [[ -z "$VERSION" ]]; then
  fail "version in pubspec.yaml is empty"
fi

TAG="v$VERSION"

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

ARTIFACT_NAME="FreeObmin_v${VERSION}.apk"
ARTIFACT_PATH="build/app/outputs/flutter-apk/${ARTIFACT_NAME}"
cp -f "$APK_PATH" "$ARTIFACT_PATH"

git tag "$TAG" -m "Release $TAG"
git push origin "$TAG"

if gh release view "$TAG" $REPO_ARG >/dev/null 2>&1; then
  echo "updating existing release $TAG"
  gh release upload "$TAG" $REPO_ARG "$ARTIFACT_PATH" --clobber
else
  echo "creating release $TAG"
  gh release create "$TAG" $REPO_ARG "$ARTIFACT_PATH" \
    --title "$TAG" \
    --notes "$RELEASE_NOTES" \
    --target "$(git rev-parse HEAD)"
fi

echo "release $TAG published to ${OWNER}/${REPO}"
