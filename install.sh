#!/usr/bin/env sh
# Installs the map skill into orchestrator skill dirs as links.
# Default targets: ~/.claude/skills/map and ~/.grok/skills/map
# - Unix: symlink
# - Windows (Git Bash / MSYS): directory junction via PowerShell
# Re-running is safe: replaces an existing link, refuses to clobber a real directory.
set -eu

repo_skill="$(cd "$(dirname "$0")/skill" && pwd)"

[ -f "$repo_skill/SKILL.md" ] || {
  echo "skill/SKILL.md not found - run from the repo root." >&2
  exit 1
}

# Optional: MAP_INSTALL_TARGETS="claude" or "grok" or "claude,grok" (default both)
targets_csv="${MAP_INSTALL_TARGETS:-claude,grok}"

is_windows() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

to_win_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

# Remove an existing skill link (symlink or Windows junction). Never rm -rf.
remove_existing_link() {
  target="$1"

  if [ -L "$target" ]; then
    rm "$target"
    return 0
  fi

  if [ ! -e "$target" ]; then
    return 0
  fi

  if is_windows && [ -d "$target" ]; then
    win=$(to_win_path "$target")
    # PowerShell: remove only if reparse point (junction/symlink)
    if powershell.exe -NoProfile -Command \
      "\$i = Get-Item -LiteralPath '$win' -Force; if (\$i.Attributes -band [IO.FileAttributes]::ReparsePoint) { Remove-Item -LiteralPath '$win' -Force; exit 0 } else { exit 2 }" \
      >/dev/null 2>&1; then
      return 0
    fi
  fi

  echo "$target exists and is a real directory, not a link. Remove it manually if you intend to replace it." >&2
  exit 1
}

link_one() {
  skills_dir="$1"
  target="$skills_dir/map"

  mkdir -p "$skills_dir"
  remove_existing_link "$target"

  if is_windows; then
    win_target=$(to_win_path "$target")
    win_skill=$(to_win_path "$repo_skill")
    if ! powershell.exe -NoProfile -Command \
      "New-Item -ItemType Junction -Path '$win_target' -Target '$win_skill' | Out-Null"; then
      echo "Failed to create junction: $target -> $repo_skill" >&2
      echo "On Windows, prefer: powershell -File install.ps1" >&2
      exit 1
    fi
  else
    ln -s "$repo_skill" "$target"
  fi

  echo "Installed: $target -> $repo_skill"
}

# Portable comma-split without arrays
old_ifs=$IFS
IFS=,
for name in $targets_csv; do
  IFS=$old_ifs
  name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -n "$name" ] || continue
  case "$name" in
    claude) link_one "$HOME/.claude/skills" ;;
    grok)   link_one "$HOME/.grok/skills" ;;
    *)
      echo "Unknown install target '$name' (use claude and/or grok)." >&2
      exit 1
      ;;
  esac
  IFS=,
done
IFS=$old_ifs

echo "Update anytime with: git pull (the link tracks this clone)."
echo "Override targets: MAP_INSTALL_TARGETS=claude ./install.sh"
