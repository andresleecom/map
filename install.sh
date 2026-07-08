#!/usr/bin/env sh
# Installs the map skill into ~/.claude/skills/map as a symlink.
# Re-running is safe: replaces an existing link, refuses to clobber a real directory.
set -eu

repo_skill="$(cd "$(dirname "$0")/skill" && pwd)"
skills_dir="$HOME/.claude/skills"
target="$skills_dir/map"

[ -f "$repo_skill/SKILL.md" ] || { echo "skill/SKILL.md not found — run from the repo root." >&2; exit 1; }

mkdir -p "$skills_dir"

if [ -e "$target" ] || [ -L "$target" ]; then
  if [ -L "$target" ]; then
    rm "$target"
  else
    echo "$target exists and is a real directory, not a link. Remove it manually if you intend to replace it." >&2
    exit 1
  fi
fi

ln -s "$repo_skill" "$target"
echo "Installed: $target -> $repo_skill"
echo "Update anytime with: git pull (the symlink tracks this clone)."
