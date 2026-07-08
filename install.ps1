# Installs the map skill into ~/.claude/skills/map as a junction (no admin needed).
# Re-running is safe: replaces an existing link, refuses to clobber a real directory.

$ErrorActionPreference = 'Stop'

$repoSkill = Join-Path $PSScriptRoot 'skill'
$skillsDir = Join-Path $env:USERPROFILE '.claude\skills'
$target    = Join-Path $skillsDir 'map'

if (-not (Test-Path (Join-Path $repoSkill 'SKILL.md'))) {
    throw "skill/SKILL.md not found next to install.ps1 — run this from the repo root."
}

New-Item -ItemType Directory -Force $skillsDir | Out-Null

if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType) {
        Remove-Item $target -Force -Confirm:$false
    } else {
        throw "$target exists and is a real directory, not a link. Remove it manually if you intend to replace it."
    }
}

New-Item -ItemType Junction -Path $target -Target $repoSkill | Out-Null
Write-Host "Installed: $target -> $repoSkill"
Write-Host "Update anytime with: git pull (the junction tracks this clone)."
