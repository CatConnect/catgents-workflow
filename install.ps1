# CatAgents — Install Script
# Instala worker e pr globalmente em ~/.claude/skills/
# Usage: .\install.ps1

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir  = Join-Path $env:USERPROFILE ".claude\skills"

Write-Host "🐱 CatAgents Installer" -ForegroundColor Cyan
Write-Host ""

# Verificar gh CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  gh (GitHub CLI) não encontrado." -ForegroundColor Yellow
    Write-Host "   Instale em: https://cli.github.com"
    Write-Host "   Os workers precisam do gh para funcionar."
    Write-Host ""
}

# Criar diretório de skills
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

# Instalar skills
Write-Host "📦 Instalando skills em $SkillsDir ..." -ForegroundColor Green

foreach ($skill in @("worker", "pr")) {
    $src = Join-Path $ScriptDir "skills\$skill"
    $dst = Join-Path $SkillsDir $skill
    if (Test-Path $src) {
        if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
        Copy-Item -Recurse -Force $src $SkillsDir
        Write-Host "   ✓ $skill" -ForegroundColor White
    } else {
        Write-Host "   ⚠ $skill não encontrado — pulado" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Instalado!" -ForegroundColor Green
Write-Host ""
Write-Host "Workers disponíveis (abra um terminal por worker):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Código:      /worker triage | dev | dev-jules | qa | reviewer"
Write-Host "  Descoberta:  /worker scout | qa-monitor | security | deps"
Write-Host "  Produto:     /worker pm | ux | prioritizer"
Write-Host "  Operações:   /worker stale | release"
Write-Host ""
Write-Host "  Antes de ship:  /pr"
Write-Host ""
Write-Host "Requisito: gh auth status (GitHub CLI autenticado)" -ForegroundColor Yellow
Write-Host ""
