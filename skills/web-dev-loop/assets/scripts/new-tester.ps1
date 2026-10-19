<#
.SYNOPSIS
  Registra un tester nuevo en un proyecto: crea su contrato, sus baterias y lo anota en el registro.

.DESCRIPTION
  Un tester = un dominio (ui, db, quality, api, perf, security) que sabe atacar una cosa.
  Este script deja el tester listo para lanzar:
    1. agents/tester-<dominio>.md   (contrato con las secciones obligatorias)
    2. scripts/tester-<dominio>/      (lib.mjs + bateria de ejemplo)
    3. testing/registry.json         (alta del tester con sus capacidades y adapters)

.EXAMPLE
  powershell -File scripts/new-tester.ps1 -Domain db -Name "Tester de base de datos" `
    -Capabilities invariantes,indices,concurrencia -Adapter sql
#>
param(
  [Parameter(Mandatory = $true)][string]$Domain,
  [string]$Name = '',
  [string]$Capabilities = 'correccion,estados-rotos,limites',
  [string]$Adapter = 'sql',
  [string]$ProjectPath = '.'
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$KitRoot = Split-Path -Parent $PSScriptRoot
$ProjectPath = (Resolve-Path $ProjectPath).Path

# Windows PowerShell 5.1 escribe BOM con -Encoding utf8 y eso rompe los parsers de JSON.
function Write-Utf8NoBom([string]$FilePath, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($FilePath, $Content, $enc)
}

if (-not $Name) { $Name = "Tester de $Domain" }
$caps = @($Capabilities -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

Write-Host "Registrando tester '$Domain' en $ProjectPath"

# --- 1. contrato del agente -------------------------------------------------
$agentsDir = Join-Path $ProjectPath 'agents'
New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
$agentPath = Join-Path $agentsDir "tester-$Domain.md"

$template = Join-Path $KitRoot "agents\tester-$Domain.md"
if (Test-Path $template) {
  Copy-Item $template $agentPath -Force
  Write-Host "  contrato copiado desde la plantilla del kit"
} else {
  # Plantilla generica. Here-string SIMPLES (comillas simples) para que los backticks
  # del markdown no se interpreten como escapes de PowerShell; los huecos se reemplazan
  # despues con -replace.
  $generic = @'
# Tester de __DOMAIN__ - contrato

## Rol

Sos el **tester adversarial de __DOMAIN__**. Atacas el proyecto en su dominio, reproduces
cada hallazgo con un repro que falla primero, y arreglas lo que corresponde.

## Lectura obligatoria

1. `AGENTS.md` del proyecto.
2. `docs/lessons.md` (clases de fallo acumuladas).
3. `testing/adapters/__ADAPTER__.md` (la herramienta que vas a usar).
4. La spec de la ronda y el informe del dev, para verificar sus claims con tus propios ojos.

## Alcance

- Escribis el codigo de las baterias y los fixes de app que correspondan.
- No tocas migraciones, schema ni el modelo de dominio: eso se reporta.
- No commiteas.

## Metodo

1. Usar -> 2. Encontrar -> 3. Reproducir (falla primero) -> 4. Arreglar -> 5. Verificar
   (bateria propia + regresion de la ronda anterior) -> 6. Reportar.

## Ataques (adaptalos al brief)

- Correccion del dominio: el valor esperado, calculado a mano.
- Estados rotos: vacio, error, cargando, parcial.
- Limites: tamanos, cantidades, longitudes -> 4xx accionable, nunca 500.
- Idempotencia y concurrencia: doble submit, N requests en paralelo.

## Entregables

1. Baterias durables en `scripts/tester-__DOMAIN__/` con el harness comun.
2. Informe en `%TEMP%\<kit>\informe-tester-__DOMAIN__-<ronda>.md`: tabla de baterias, bugs
   con repro/causa/arreglo/verificacion, bugs no arreglados, claims del dev verificados,
   numeros canonicos, estado dejado y `VEREDICTO: VERDE|ROJO`.
3. Memoria (Engram).
4. Mensaje final que empiece con `VEREDICTO:`.

## Cierre

Limpia lo que creaste (por id), no commitees y no dejes runners vivos.
'@
  $generic = $generic.Replace('__DOMAIN__', $Domain).Replace('__ADAPTER__', $Adapter)
  Write-Utf8NoBom $agentPath $generic
  Write-Host "  contrato generado desde la plantilla generica"
}

# --- 2. carpeta de baterias -------------------------------------------------
$batsDir = Join-Path $ProjectPath "scripts\tester-$Domain"
New-Item -ItemType Directory -Force -Path $batsDir | Out-Null

$lib = @'
// Wrapper de batteries: reexporta el harness comun.
export { suite, run } from "../../tools/harness.mjs";
'@
Write-Utf8NoBom (Join-Path $batsDir 'lib.mjs') $lib

$demo = @'
import { suite } from "./lib.mjs";

const t = await suite("__DOMAIN__-00-demo", { file: import.meta.url });
t.check("reemplazar por un ataque real", true, "bateria de ejemplo");
await t.finish();
'@
$demo = $demo.Replace('__DOMAIN__', $Domain)
Write-Utf8NoBom (Join-Path $batsDir '00-demo.mjs') $demo
Write-Host "  baterias en scripts/tester-$Domain/"

# --- 3. registro ------------------------------------------------------------
$registryPath = Join-Path $ProjectPath 'testing\registry.json'
if (-not (Test-Path $registryPath)) {
  Write-Error "No existe testing/registry.json en $ProjectPath (proyecto mal inicializado?)"
}
$registry = Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json

$existing = @($registry.testers | Where-Object { $_.id -eq $Domain })
if ($existing.Count -gt 0) {
  Write-Host "  el tester '$Domain' ya estaba registrado: se actualiza"
  $entry = $existing[0]
} else {
  $entry = [pscustomobject]@{
    id           = $Domain
    domain       = $Domain
    agent        = "agents/tester-$Domain.md"
    capabilities = @()
    adapters     = @()
    batteries    = "scripts/tester-$Domain/"
    regression   = ''
    budget       = [pscustomobject]@{ maxRuntimeMin = 45 }
  }
  $registry.testers = @($registry.testers) + $entry
}

$entry.agent = "agents/tester-$Domain.md"
$entry.capabilities = $caps
$entry.adapters = @($Adapter)

$registryJson = ($registry | ConvertTo-Json -Depth 10)
Write-Utf8NoBom $registryPath $registryJson
Write-Host "  registrado en testing/registry.json (capabilities: $($caps -join ', ') | adapter: $Adapter)"

Write-Host ''
Write-Host 'Listo. Para lanzarlo, desde el orquestador:'
Write-Host "  subagent(agent: 'general', description: 'Tester $Domain', prompt: 'Le agents/tester-$Domain.md ...')"
Write-Host "  y acorda el loop: tester -> gate -> cierre (ver agents/README.md)"
