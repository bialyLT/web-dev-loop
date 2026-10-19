<#
.SYNOPSIS
  Crea un proyecto web nuevo con el kit instalado (agentes, testing, tools, docs, config).

.DESCRIPTION
  Copia la estructura del kit al proyecto nuevo, sustituye los {{...}} de la
  configuracion con los valores que le pases y deja el registry con un tester
  de UI registrado (el primero que siempre existe).

.EXAMPLE
  powershell -File scripts/new-project.ps1 -Name mi-app -Path C:\ruta -Port 3100
#>
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Path,
  [int]$Port = 3100,
  [int]$DbPort = 5433,
  [string]$Stack = 'Next.js 16 (App Router) + Prisma + PostgreSQL 17',
  [string]$Model = '',
  [string]$TypecheckCmd = 'npm run typecheck',
  [string]$TestCmd = 'npm test',
  [string]$SmokeCmd = 'npm run smoke -- --reset',
  [string]$BuildCmd = 'npm run build',
  [string]$FlowsCmd = 'powershell -File scripts/flows.ps1',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$KitRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'
$Target = Join-Path $Path $Name

# Windows PowerShell 5.1 escribe BOM con -Encoding utf8 y eso rompe los parsers de JSON.
function Write-Utf8NoBom([string]$FilePath, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($FilePath, $Content, $enc)
}

if (Test-Path $Target) {
  $items = @(Get-ChildItem $Target -Force -ErrorAction SilentlyContinue)
  if ($items.Count -gt 0 -and -not $Force) {
    Write-Error "El destino ya existe y no esta vacio: $Target (usa -Force para continuar)"
  }
}

Write-Host "Creando $Target" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $Target | Out-Null

# --- estructura -------------------------------------------------------------
$dirs = @(
  'agents', 'docs', 'memory', 'reports', 'scripts', 'scripts/tester-ui',
  'testing', 'testing/adapters', 'tools', 'tools/example', 'flows'
)
foreach ($d in $dirs) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Target $d) | Out-Null
}

# --- archivos base ----------------------------------------------------------
Copy-Item (Join-Path $KitRoot 'agents\README.md')          (Join-Path $Target 'agents\README.md') -Force
Copy-Item (Join-Path $KitRoot 'agents\orchestrator.md')    (Join-Path $Target 'agents\orchestrator.md') -Force
Copy-Item (Join-Path $KitRoot 'agents\dev.md')             (Join-Path $Target 'agents\dev.md') -Force
Copy-Item (Join-Path $KitRoot 'agents\tester-ui.md')       (Join-Path $Target 'agents\tester-ui.md') -Force
Copy-Item (Join-Path $KitRoot 'testing\README.md')         (Join-Path $Target 'testing\README.md') -Force
Copy-Item (Join-Path $KitRoot 'testing\adapters\*.md')    (Join-Path $Target 'testing\adapters') -Force
Copy-Item (Join-Path $KitRoot 'tools\harness.mjs')         (Join-Path $Target 'tools\harness.mjs') -Force
Copy-Item (Join-Path $KitRoot 'tools\run-batteries.mjs')   (Join-Path $Target 'tools\run-batteries.mjs') -Force
Copy-Item (Join-Path $KitRoot 'tools\example\*.mjs')       (Join-Path $Target 'tools\example') -Force
Copy-Item (Join-Path $KitRoot 'docs\lessons.md')           (Join-Path $Target 'docs\lessons.md') -Force
Copy-Item (Join-Path $KitRoot 'memory\engram-protocol.md') (Join-Path $Target 'memory\engram-protocol.md') -Force

# --- sustituciones ---------------------------------------------------------
$dbBase = ($Name -replace '[^a-zA-Z0-9_]', '_').ToLower()
$tokens = [ordered]@{
  '{{PROJECT_NAME}}' = $Name
  '{{ONE_LINER}}'   = "TODO: una frase que diga que es $Name."
  '{{STACK}}'       = $Stack
  '{{MODEL}}'       = $Model
  '{{APP_PORT}}'    = $Port
  '{{DB_PORT}}'     = $DbPort
  '{{DB_DEV}}'      = "${dbBase}_dev"
  '{{DB_TEST}}'     = "${dbBase}_test"
  '{{APP_URL}}'     = "http://127.0.0.1:$Port"
  '{{INSTALL_CMD}}' = 'npm install'
  '{{DEV_CMD}}'     = 'npm run dev'
  '{{BUILD_CMD}}'   = $BuildCmd
  '{{TEST_CMD}}'    = $TestCmd
  '{{SMOKE_CMD}}'   = $SmokeCmd
  '{{FLOWS_CMD}}'   = $FlowsCmd
  '{{TYPECHECK_CMD}}' = $TypecheckCmd
  '{{PG_DIR}}'      = 'TODO: ruta del Postgres portable'
  '{{DB_START_CMD}}' = 'npm run db:local:start'
  '{{SCRATCH_DIR}}' = '.atl'
  '{{INVARIANTS}}'  = "TODO: las invariantes criticas (CHECK / indice unico / trigger) de $Name."
  '{{DOMAIN_RULE_1}}' = 'TODO: la regla central del dominio.'
  '{{DOMAIN_RULE_2}}' = 'TODO: la segunda regla que no se negocia.'
  '{{ENGRAM_CMD}}'  = 'TODO: ruta al ejecutable de Engram (engram mcp --tools=agent)'
}

function Replace-Tokens([string]$text) {
  foreach ($k in $tokens.Keys) { $text = $text.Replace($k, [string]$tokens[$k]) }
  return $text
}

$agents = Replace-Tokens (Get-Content (Join-Path $KitRoot 'AGENTS.template.md') -Raw -Encoding UTF8)
Write-Utf8NoBom (Join-Path $Target 'AGENTS.md') $agents

$opencode = Replace-Tokens (Get-Content (Join-Path $KitRoot 'opencode.template.jsonc') -Raw -Encoding UTF8)
if ([string]::IsNullOrWhiteSpace($Model)) {
  # sin modelo, la linea se deja comentada: un "model": "" rompe el arranque
  $opencode = $opencode -replace '(?m)^(\s*)"model":\s*"",\s*$', '$1// "model": "<provider/model>",'
}
Write-Utf8NoBom (Join-Path $Target 'opencode.jsonc') $opencode

$registry = Replace-Tokens (Get-Content (Join-Path $KitRoot 'testing\registry.template.json') -Raw -Encoding UTF8)
Write-Utf8NoBom (Join-Path $Target 'testing\registry.json') $registry

# --- .gitignore -------------------------------------------------------------
$gitignore = @"
node_modules/
.next/
out/
dist/
.env
.env.*
!.env.example
reports/
$($tokens['{{SCRATCH_DIR}}'])/

# documentos locales: el repo lleva codigo, tests y docs de uso, no bitacoras
ROADMAP.md
*.log
"@
Write-Utf8NoBom (Join-Path $Target '.gitignore') $gitignore

# --- CONTEXTO.md (handoff) --------------------------------------------------
$contexto = @"
# Contexto del proyecto

Documento de traspaso: que es la app, en que estado esta, y cual es el proximo paso.
Ultima actualizacion: $(Get-Date -Format 'yyyy-MM-dd').

## Que es

$($tokens['{{ONE_LINER}}'])

## Estado verificado

- Gates: TODO (typecheck / tests / smoke / build / flows con numeros).
- Bugs abiertos: ninguno.
- Memoria: Engram (buscar por proyecto).

## Decisiones que no se negocian

1. $($tokens['{{DOMAIN_RULE_1}}'])
2. $($tokens['{{DOMAIN_RULE_2}}'])

## Proximo paso

TODO.
"@
Write-Utf8NoBom (Join-Path $Target 'CONTEXTO.md') $contexto

# --- bateria de ejemplo -----------------------------------------------------
$lib = @'
// Wrapper de batteries del tester de UI.
export { suite, run } from "../../tools/harness.mjs";
'@
Write-Utf8NoBom (Join-Path $Target 'scripts\tester-ui\lib.mjs') $lib

$demo = @'
// Bateria de ejemplo: reemplacala por tus ataques reales.
import { suite } from "./lib.mjs";

const t = await suite("ui-00-demo", { file: import.meta.url });
t.check("la app responde 200", true, "reemplazar por una peticion real");
t.equal("el harness responde", 1 + 1, 2);
await t.finish();
'@
Write-Utf8NoBom (Join-Path $Target 'scripts\tester-ui\00-demo.mjs') $demo

# --- resumen ----------------------------------------------------------------
Write-Host ''
Write-Host 'Proyecto creado:' -ForegroundColor Green
Write-Host "  $Target"
Write-Host ''
Write-Host 'Pendientes de completar (TODO en el proyecto):' -ForegroundColor Yellow
Select-String -Path (Join-Path $Target 'AGENTS.md'), (Join-Path $Target 'opencode.jsonc'), (Join-Path $Target 'testing\registry.json') -Pattern 'TODO' -CaseSensitive |
  ForEach-Object { "  $($_.Path):$($_.LineNumber)  $($_.Line.Trim())" } | Select-Object -Unique
Write-Host ''
Write-Host 'Proximos pasos:'
Write-Host "  cd `"$Target`""
Write-Host '  npm install'
Write-Host '  node tools/example/demo-battery.mjs        # smoke test del kit'
Write-Host '  node tools/run-batteries.mjs --glob "scripts/tester-*/0*.mjs"'
Write-Host ''
Write-Host 'El registro de agentes y gates esta en testing/registry.json'
