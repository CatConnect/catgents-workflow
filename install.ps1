# CatAgents — Install Script (Windows)
# Instala dependencias e skills em ~/.claude/skills/ e ~/.verboo/skills/
# Usage: .\install.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "CatAgents Installer" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Verificar gh CLI ──────────────────────────────────────────────────────
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: gh (GitHub CLI) nao encontrado." -ForegroundColor Red
    Write-Host "      Instale em: https://cli.github.com e tente novamente."
    exit 1
}
Write-Host "OK  gh CLI encontrado" -ForegroundColor Green

# ─── 2. Instalar jq (necessario para os workers) ─────────────────────────────
$jqPath = "$env:ProgramFiles\Git\usr\bin\jq.exe"
$jqAlt  = "$env:USERPROFILE\bin\jq.exe"

$hasJq = (Get-Command jq -ErrorAction SilentlyContinue) -or (Test-Path $jqPath) -or (Test-Path $jqAlt)

if (-not $hasJq) {
    Write-Host "Instalando jq..." -ForegroundColor Yellow

    # Tenta winget primeiro
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id jqlang.jq --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Write-Host "OK  jq instalado via winget" -ForegroundColor Green
    } else {
        # Fallback: download direto para Git Bash
        $jqUrl = "https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe"
        $jqDest = $jqPath

        $gitBinDir = Split-Path $jqDest
        if (-not (Test-Path $gitBinDir)) {
            # Git Bash nao existe nesse caminho, usar ~/bin
            New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\bin" | Out-Null
            $jqDest = $jqAlt
        }

        try {
            Invoke-WebRequest -Uri $jqUrl -OutFile $jqDest -UseBasicParsing
            Write-Host "OK  jq baixado para $jqDest" -ForegroundColor Green
            Write-Host "    Adicione '$( Split-Path $jqDest )' ao PATH do Git Bash se necessario." -ForegroundColor Yellow
        } catch {
            Write-Host "AVISO: nao foi possivel baixar jq automaticamente." -ForegroundColor Yellow
            Write-Host "       Baixe manualmente: https://jqlang.github.io/jq/download/" -ForegroundColor Yellow
            Write-Host "       Coloque jq.exe em: C:\Program Files\Git\usr\bin\" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "OK  jq encontrado" -ForegroundColor Green
}

# ─── 3. Instalar skills ───────────────────────────────────────────────────────
$targets = @(
    "$env:USERPROFILE\.claude\skills",
    "$env:USERPROFILE\.verboo\skills"
)

foreach ($skillsDir in $targets) {
    if (-not (Test-Path (Split-Path $skillsDir))) { continue }  # pasta pai nao existe (ex: verboo nao instalado)

    New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
    Write-Host ""
    Write-Host "Instalando em $skillsDir ..." -ForegroundColor Cyan

    foreach ($skill in @("worker")) {
        $src = Join-Path $ScriptDir "skills\$skill"
        if (Test-Path $src) {
            $dst = Join-Path $skillsDir $skill
            if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
            Copy-Item -Recurse -Force $src $skillsDir
            Write-Host "   OK  $skill" -ForegroundColor Green
        } else {
            Write-Host "   AVISO: $skill nao encontrado em $src" -ForegroundColor Yellow
        }
    }
}

# ─── 4. Resultado ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Instalacao concluida!" -ForegroundColor Green
Write-Host ""
Write-Host "Uso (abra um terminal por worker, dentro do clone do repo alvo):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  /worker team-manager   # orquestrador — comece por ele"
Write-Host "  /worker dev            # implementa issues assignadas"
Write-Host "  /worker qa             # revisa PRs assignadas"
Write-Host "  /worker reviewer       # mergeia PRs aprovadas"
Write-Host "  /worker scout          # varredura passiva (opcional)"
Write-Host ""
Write-Host "Requisito: gh auth login (GitHub CLI autenticado)" -ForegroundColor Yellow
Write-Host ""
