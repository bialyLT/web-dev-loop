<#
.SYNOPSIS
  Instala la skill web-dev-loop y los agentes nativos en la configuracion global de OpenCode.

.DESCRIPTION
  Copia:
    <config>\skills\web-dev-loop\   (SKILL.md + references + scripts + assets)
    <config>\agents\*.md            (dev, tester-ui, tester-db, tester-quality, security-auditor)

  Los agentes globales aplican a TODOS los proyectos. Un proyecto puede sobrescribir la
  skill con .opencode\skills\web-dev-loop\.

.EXAMPLE
  powershell -File install.ps1
  powershell -File install.ps1 -ConfigDir "D:\config\opencode"
#>
param(
  [string]$ConfigDir = "$env:USERPROFILE\.config\opencode",
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot
$SkillSrc = Join-Path $Repo 'skills\web-dev-loop'
$AgentsSrc = Join-Path $Repo 'agents'

if (-not (Test-Path $SkillSrc)) { Write-Error "No encuentro skills\web-dev-loop en $Repo" }
if (-not (Test-Path $AgentsSrc)) { Write-Error "No encuentro agents\ en $Repo" }

Write-Host "Repo:   $Repo"
Write-Host "Config: $ConfigDir"
Write-Host ''

New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir 'skills') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir 'agents') | Out-Null

$skillDst = Join-Path $ConfigDir 'skills\web-dev-loop'
if ((Test-Path $skillDst) -and -not $Force) {
  Write-Host "La skill ya existe en $skillDst" -ForegroundColor Yellow
  Write-Host 'Se reemplaza igual (la version del repo es la fuente). Usá -Force para confirmarlo.' -ForegroundColor Yellow
}
if (Test-Path $skillDst) { Remove-Item $skillDst -Recurse -Force }
Copy-Item $SkillSrc $skillDst -Recurse -Force
Write-Host "Skill instalada: $skillDst" -ForegroundColor Green

Copy-Item (Join-Path $AgentsSrc '*.md') (Join-Path $ConfigDir 'agents') -Force
Write-Host "Agentes instalados: $ConfigDir\agents" -ForegroundColor Green
Get-ChildItem (Join-Path $ConfigDir 'agents') -File | ForEach-Object { "  - $($_.Name)" }

Write-Host ''
Write-Host 'Listo.' -ForegroundColor Green
Write-Host 'La skill se anuncia sola cuando el pedido encaja (roadmap, propuesta, fase, testers).'
Write-Host 'Para usarla de forma explicita: @web-dev-loop'
Write-Host ''
Write-Host 'Opcional: pegar el bloque de MCPs (context7 / memoria) en tu opencode.json.'
Write-Host 'No instales el MCP de Maestro si usas el CLI de Maestro: pelean el lock de sesion.'
