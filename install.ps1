# Installs the map skill into orchestrator skill dirs as junctions (no admin needed).
# Default targets: ~/.claude/skills/map, ~/.grok/skills/map, ~/.agents/skills/map (Kimi Code)
# Re-running is safe: replaces an existing link, refuses to clobber a real directory.
#
# Override: $env:MAP_INSTALL_TARGETS = "claude"  # or "grok" or "kimi" or "claude,grok,kimi"

$ErrorActionPreference = 'Stop'

$repoSkill = Join-Path $PSScriptRoot 'skill'

if (-not (Test-Path (Join-Path $repoSkill 'SKILL.md'))) {
    throw "skill/SKILL.md not found next to install.ps1 - run this from the repo root."
}

$targetsCsv = if ($env:MAP_INSTALL_TARGETS) { $env:MAP_INSTALL_TARGETS } else { 'claude,grok,kimi' }

function Test-IsLinkLike {
    param([System.IO.FileSystemInfo]$Item)
    if ($Item.LinkType) { return $true }
    return [bool]($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Install-MapSkillLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsDir
    )

    $target = Join-Path $SkillsDir 'map'

    New-Item -ItemType Directory -Force $SkillsDir | Out-Null

    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if (Test-IsLinkLike $item) {
            # Junction / symlink: remove the link only, never the target's contents.
            # Remove-Item throws NullReferenceException on junctions under Windows
            # PowerShell 5.1; FileSystemInfo.Delete() removes the reparse point itself.
            $item.Delete()
        } else {
            throw "$target exists and is a real directory, not a link. Remove it manually if you intend to replace it."
        }
    }

    New-Item -ItemType Junction -Path $target -Target $repoSkill | Out-Null
    Write-Host "Installed: $target -> $repoSkill"
}

foreach ($raw in ($targetsCsv -split ',')) {
    $name = $raw.Trim().ToLowerInvariant()
    if (-not $name) { continue }
    switch ($name) {
        'claude' { Install-MapSkillLink -SkillsDir (Join-Path $env:USERPROFILE '.claude\skills') }
        'grok'   { Install-MapSkillLink -SkillsDir (Join-Path $env:USERPROFILE '.grok\skills') }
        'kimi'   { Install-MapSkillLink -SkillsDir (Join-Path $env:USERPROFILE '.agents\skills') }
        default  { throw "Unknown install target '$name' (use claude, grok and/or kimi)." }
    }
}

Write-Host "Update anytime with: git pull (the junction tracks this clone)."
Write-Host 'Override targets: $env:MAP_INSTALL_TARGETS = "claude"; .\install.ps1'
