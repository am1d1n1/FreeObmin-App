# freeobmin_flutter

A Flutter application for exchanging items without money.

## Getting Started

This repository is a working project for the FreeObmin mobile app.

Familiarize yourself with the Flutter tooling before you begin:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## Automated release workflow

The helper script `scripts/publish_release.sh` compiles the release APK, tags
the current commit, pushes the tag, and publishes the artifact to GitHub
Releases so that the in-app update checker can find the latest version.

1. Install the [GitHub CLI](https://cli.github.com/) and run `gh auth login`.
2. Fill in `GITHUB_UPDATE_OWNER` and `GITHUB_UPDATE_REPO` in `.env`.
3. Keep the working tree clean (`git status --short` should show nothing).
4. Run the release script:

```bash
bash scripts/publish_release.sh
```

If you need custom release notes, provide them via the `RELEASE_NOTES`
environment variable:

```bash
RELEASE_NOTES="Fixed issues with Firebase auth" bash scripts/publish_release.sh
```

The version tag is derived from the `version` field in `pubspec.yaml`, so
every time you bump the version you will publish a new GitHub Release and the
app’s update checker will detect a newer build automatically.
