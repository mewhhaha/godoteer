#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
PUBLISH_DIR="$(mktemp -d)"

cleanup() {
  if git -C "$ROOT_DIR" worktree list | grep -Fq "$PUBLISH_DIR"; then
    git -C "$ROOT_DIR" worktree remove --force "$PUBLISH_DIR" || true
  fi
  rm -rf "$PUBLISH_DIR"
}

trap cleanup EXIT

git fetch origin main || true

if git show-ref --verify --quiet refs/remotes/origin/main; then
  git worktree add --detach "$PUBLISH_DIR" origin/main
else
  git worktree add --detach "$PUBLISH_DIR"
  git -C "$PUBLISH_DIR" checkout --orphan main
fi

find "$PUBLISH_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

cp README.md "$PUBLISH_DIR/README.md"
cp -R docs "$PUBLISH_DIR/docs"
cp -R sample_project/addons/godoteer/. "$PUBLISH_DIR/"

git -C "$PUBLISH_DIR" add -A

if git -C "$PUBLISH_DIR" diff --cached --quiet; then
  echo "No publish changes."
  exit 0
fi

git -C "$PUBLISH_DIR" config user.name "github-actions[bot]"
git -C "$PUBLISH_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git -C "$PUBLISH_DIR" commit -m "Publish addon package from dev" -m "Generated from dev branch.\n\nCo-authored-by: Codex <noreply@openai.com>"
git -C "$PUBLISH_DIR" push origin HEAD:main --force
