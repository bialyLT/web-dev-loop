// run-batteries.mjs — corre varias baterias y agrega los numeros.
//
//   node tools/run-batteries.mjs --glob "scripts/tester-<dominio>/0*.mjs" --out reports/summary.json
//   node tools/run-batteries.mjs --glob "scripts/tester-<dominio>/0*.mjs" --filter db --timeout-min 20
//
// Salida: una linea por bateria + totales. Exit code 1 si alguna bateria fallo.
// Es la herramienta que permite que el orquestador sume numeros de testers de
// dominios distintos sin saber nada de cada dominio.

import { spawn } from "node:child_process";
import { mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";

const args = process.argv.slice(2);
const opt = (name, fallback = null) => {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const value = args[i + 1];
  return value && !value.startsWith("--") ? value : true;
};

const glob = String(opt("glob", "scripts/tester-*/0*.mjs"));
const filter = opt("filter", null);
const outFile = String(opt("out", join("reports", "summary.json")));
const timeoutMin = Number(opt("timeout-min", 45));
const root = process.cwd();

/** Convierte un glob (soporta **, * y ?) a regex sobre rutas con separador /. */
function globToRegExp(pattern) {
  const normalized = pattern.split(sep).join("/");
  let re = "";
  for (let i = 0; i < normalized.length; i++) {
    const ch = normalized[i];
    if (ch === "*") {
      if (normalized[i + 1] === "*") {
        i++;
        if (normalized[i + 1] === "/") {
          i++;
          re += "(?:.*/)?";
        } else {
          re += ".*";
        }
      } else {
        re += "[^/]*";
      }
    } else if (ch === "?") {
      re += "[^/]";
    } else if ("\\^$.|+()[]{}".includes(ch)) {
      re += "\\" + ch;
    } else {
      re += ch;
    }
  }
  return new RegExp(`^${re}$`);
}

function walk(dir, acc = []) {
  let entries = [];
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return acc;
  }
  for (const entry of entries) {
    if (entry.name === "node_modules" || entry.name === ".git" || entry.name === ".next")
      continue;
    const full = join(dir, entry.name);
    if (entry.isDirectory()) walk(full, acc);
    else acc.push(full);
  }
  return acc;
}

function expand(pattern) {
  const re = globToRegExp(pattern);
  return walk(root)
    .map((f) => relative(root, f).split(sep).join("/"))
    .filter((f) => re.test(f))
    .sort();
}

function parseResult(stdout) {
  const match = stdout.match(/RESULT ok=(\d+) fail=(\d+)(?: skip=(\d+))?/);
  if (!match) return null;
  return { ok: Number(match[1]), fail: Number(match[2]), skip: Number(match[3] ?? 0) };
}

function runBattery(file) {
  return new Promise((resolvePromise) => {
    const started = Date.now();
    const child = spawn(process.execPath, [file], {
      cwd: root,
      env: { ...process.env, KIT_REPORT_DIR: process.env.KIT_REPORT_DIR ?? join(root, "reports") },
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMin * 60 * 1000);

    child.stdout.on("data", (d) => (stdout += d.toString()));
    child.stderr.on("data", (d) => (stderr += d.toString()));
    child.on("close", (code) => {
      clearTimeout(timer);
      const parsed = parseResult(stdout);
      resolvePromise({
        file,
        exitCode: code,
        timedOut,
        ms: Date.now() - started,
        ok: parsed?.ok ?? 0,
        fail: parsed?.fail ?? (code === 0 ? 0 : 1),
        skip: parsed?.skip ?? 0,
        stdout,
        stderr,
      });
    });
  });
}

const files = expand(glob)
  .filter((f) => !filter || f.includes(String(filter)))
  // las librerias compartidas no son baterias
  .filter((f) => !/(^|\/)(lib|_.*)\.mjs$/.test(f));
if (files.length === 0) {
  console.error(`No hay baterias que coincidan con ${glob}${filter ? ` (filtro ${filter})` : ""}`);
  process.exit(1);
}

console.log(`Corriendo ${files.length} bateria(s) con el patron ${glob}\n`);

const results = [];
for (const file of files) {
  const result = await runBattery(file);
  results.push(result);
  const mark = result.fail > 0 ? "FALLA" : "ok   ";
  console.log(
    `${mark} ${file.padEnd(48)} ok=${String(result.ok).padEnd(5)} fail=${String(result.fail).padEnd(4)}` +
      ` skip=${String(result.skip).padEnd(4)} ${(result.ms / 1000).toFixed(1)}s${result.timedOut ? " (TIMEOUT)" : ""}`
  );
  if (result.fail > 0) {
    const failing = result.stdout.split("\n").filter((l) => l.startsWith("[FAIL]"));
    for (const line of failing) console.log(`      ${line}`);
    if (result.stderr.trim()) console.log(`      stderr: ${result.stderr.trim().split("\n")[0]}`);
  }
}

const totals = results.reduce(
  (acc, r) => ({ ok: acc.ok + r.ok, fail: acc.fail + r.fail, skip: acc.skip + r.skip, ms: acc.ms + r.ms }),
  { ok: 0, fail: 0, skip: 0, ms: 0 }
);

console.log(
  `\nTOTAL ${totals.ok} ok / ${totals.fail} fallas / ${totals.skip} skip en ${(totals.ms / 60000).toFixed(1)} min` +
    ` (${files.length} bateria(s))`
);

try {
  mkdirSync(resolve(root, outFile).split(/[\\/]/).slice(0, -1).join("\\") || ".", { recursive: true });
} catch {
  /* el mkdir recursivo de abajo resuelve el caso normal */
}
try {
  const dir = resolve(root, outFile).replace(/[\\/][^\\/]+$/, "");
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    resolve(root, outFile),
    JSON.stringify({ glob, totals, results: results.map(({ stdout, stderr, ...rest }) => rest) }, null, 2),
    "utf8"
  );
  console.log(`Reporte: ${outFile}`);
} catch (err) {
  console.error(`No se pudo escribir ${outFile}: ${err.message}`);
}

if (totals.fail > 0) process.exitCode = 1;
