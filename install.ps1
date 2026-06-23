# CatAgents Workflow — Install Script
# Usage: .\install.ps1 [project-path]
# Installs agent-plan/init/implement into <project>\.claude\skills\
# Installs github-team into ~\.claude\skills\ (global)

param(
    [string]$ProjectPath = "."
)

Write-Host "🐱 CatAgents Workflow Installer" -ForegroundColor Cyan
Write-Host ""

# Resolve project path
if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}
$ProjectPath = (Resolve-Path $ProjectPath).Path
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "📁 Project: $ProjectPath" -ForegroundColor Yellow

# ── Project-level skills ───────────────────────────────────────────────────────

Write-Host ""
Write-Host "📋 Installing project skills into $ProjectPath\.claude\skills\ ..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path "$ProjectPath\.claude\skills" | Out-Null

foreach ($skill in @("agent-init", "agent-plan", "agent-implement")) {
    $src = Join-Path $ScriptDir "skills\$skill"
    if (Test-Path $src) {
        Copy-Item -Recurse -Force $src "$ProjectPath\.claude\skills\"
        Write-Host "   ✓ $skill" -ForegroundColor White
    } else {
        Write-Host "   ⚠ $skill not found — skipped" -ForegroundColor Yellow
    }
}

# ── Support dirs ──────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path "$ProjectPath\.agents"       | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\specs"    | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\design"   | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\tasks"    | Out-Null

# ── Config ────────────────────────────────────────────────────────────────────

$configPath = "$ProjectPath\.agents\config.json"
if (-not (Test-Path $configPath)) {
    @{
        version      = "2.0.0"
        project_type = "generic"
        quality_gates = @{
            planning    = 85
            development = 80
            validation  = 85
        }
    } | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding utf8
    Write-Host "   ✓ .agents\config.json" -ForegroundColor White
}

# ── Global skill: github-team ─────────────────────────────────────────────────

Write-Host ""
Write-Host "🌐 Installing github-team into ~\.claude\skills\ (global) ..." -ForegroundColor Green

$globalSkills = Join-Path $env:USERPROFILE ".claude\skills"
New-Item -ItemType Directory -Force -Path $globalSkills | Out-Null

$gtSrc = Join-Path $ScriptDir "skills\github-team"
if (Test-Path $gtSrc) {
    Copy-Item -Recurse -Force $gtSrc $globalSkills
    Write-Host "   ✓ github-team" -ForegroundColor White
} else {
    Write-Host "   ⚠ github-team not found — skipped" -ForegroundColor Yellow
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Project skills ($(Split-Path -Leaf $ProjectPath)):" -ForegroundColor Cyan
Write-Host "  /agent-init              — set up the territory"
Write-Host "  /agent-plan <feature>    — stalk the feature"
Write-Host "  /agent-implement <feat>  — pounce"
Write-Host ""
Write-Host "Global skill (any repo):" -ForegroundColor Cyan
Write-Host "  /github-team solo                    — all-in-one terminal"
Write-Host "  /github-team triage|backend|frontend — dedicated terminals"
Write-Host "  /github-team qa|reviewer|qa-review   — quality terminals"
Write-Host "  /github-team duo:triage-dev          — duo preset, terminal 1"
Write-Host "  /github-team duo:qa-review           — duo preset, terminal 2"
Write-Host ""
Write-Host "Tip: run 'gh auth status' to confirm GitHub CLI is authenticated." -ForegroundColor Yellow
Write-Host ""
