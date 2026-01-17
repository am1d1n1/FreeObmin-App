# GitHub Release Guide

## Purpose
This guide explains how to publish a new APK to GitHub Releases and what to do
when `bash scripts/publish_release.sh` stops with:

```
error: working tree is dirty; commit or stash changes before releasing
```

## Required tools
- Git
- GitHub CLI (`gh`)
- Flutter SDK

## 1) Update version
Edit `pubspec.yaml`:

```yaml
version: 1.2.0+3
```

- `1.2.0` becomes the tag `v1.2.0`.
- `+3` is the build number (must increase).

## 2) Commit local changes (fix for "working tree is dirty")
Check status:

```bash
git status -sb
```

If you see modified files, commit them before running the release script:

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: bump version"
git push
```

If you are not ready to commit, you can temporarily stash:

```bash
git stash
# run release script
git stash pop
```

## 3) Build + publish the release
Run the helper script from a bash shell (Git Bash/WSL):

```bash
bash scripts/publish_release.sh
```

The script will:
- build the release APK
- create and push the tag `v<version>`
- upload the APK to GitHub Releases

## 4) Common errors

### "working tree is dirty"
Reason: you have uncommitted changes.  
Fix: commit or stash as shown in step 2.

### "tag vX.Y.Z already exists"
Reason: the version in `pubspec.yaml` did not change.  
Fix: bump the version and rerun.

## 5) Useful commands

```bash
git status -sb
git add .
git commit -m "your message"
git push
```
