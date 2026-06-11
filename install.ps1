# CatConnect Agent Workflow - Install Script
# Usage: .\install.ps1 [project-path]

param(
    [string]$ProjectPath = "."
)

Write-Host "🐱 CatAgents Workflow Installer" -ForegroundColor Cyan
Write-Host ""

# Check if project path exists
if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Get absolute path
$ProjectPath = Resolve-Path $ProjectPath
Write-Host "📁 Project: $ProjectPath" -ForegroundColor Yellow

# Create directories
Write-Host "📂 Creating directories..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path "$ProjectPath\.agents\skills" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\.agents\agents" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\.agents\commands" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\specs" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\design" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectPath\docs\tasks" | Out-Null

# Get script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Copy skills
Write-Host "📋 Copying skills..." -ForegroundColor Green
Copy-Item -Recurse -Force "$ScriptDir\skills\agent-init" "$ProjectPath\.agents\skills\"
Copy-Item -Recurse -Force "$ScriptDir\skills\agent-plan" "$ProjectPath\.agents\skills\"
Copy-Item -Recurse -Force "$ScriptDir\skills\agent-implement" "$ProjectPath\.agents\skills\"

# Create config
Write-Host "⚙️ Creating configuration..." -ForegroundColor Green
$config = @{
    version = "2.0.0"
    project_type = "generic"
    cats = @{
        "scout" = @{ enabled = $true; description = "Requirements scout — maps the hunting ground" }
        "lair-builder" = @{ enabled = $true; description = "Architecture designer — builds the lair" }
        "paw-planner" = @{ enabled = $true; description = "Task planner — plans the pounce sequence" }
        "claws-dev" = @{ enabled = $true; description = "Developer — does the actual scratching" }
        "cat-tester" = @{ enabled = $true; description = "Tester — checks if the prey is actually caught" }
        "whisker-reviewer" = @{ enabled = $true; description = "Code reviewer — sniffs for problems" }
        "purr-validator" = @{ enabled = $true; description = "Final validator — only purrs when everything passes" }
    }
    quality_gates = @{
        planning = 85
        development = 80
        validation = 85
    }
} | ConvertTo-Json -Depth 10

$config | Out-File -FilePath "$ProjectPath\.agents\config.json" -Encoding UTF8

Write-Host ""
Write-Host "✅ Litter box ready!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run /agent-init              — set up the territory" -ForegroundColor White
Write-Host "  2. Run /agent-plan <feature>    — stalk the feature" -ForegroundColor White
Write-Host "  3. Run /agent-implement <feature> — pounce" -ForegroundColor White
Write-Host ""
