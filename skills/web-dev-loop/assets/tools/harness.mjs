/**
 * harness.mjs — API comun de baterias.
 *
 * Todos los testers (UI, base de datos, calidad, performance) hablan este idioma:
 *   - `check(name, cond, detail?)`  y  `equal(name, actual, expected)`
 *   - `step(name, fn)`             (captura excepciones como falla)
 *   - `skip(name, reason)`
 *   - `cleanup(fn)`                (se ejecuta al final, aunque haya fallas)
 *   - `finish()`                   (resumen + exit code + reporte JSON)
 *
 * Salida estandar (parseable por humans y por máquinas):
 *   [OK]   el total cuadra
 *   [FAIL] el total cuadra -> esperado 1500.50 | obtenido 1500.49
 *   RESULT ok=1 fail=1 skip=0 suite=db-01 file=scripts/tester-db/01.mjs ms=42
 *
 * Exit code: 0 si no hay fallas, 1 si las hay.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Acepta tanto una ruta como un file:// URL (import.meta.url). */
function toPath(file) {
  if (!file) return "";
  const raw = String(file);
  if (raw.startsWith("file:")) {
    try {
      return fileURLToPath(raw);
    } catch {
      return raw;
    }
  }
  return raw;
}

const RESET = "\u001b[0m";
const GREEN = "\u001b[32m";
const RED = "\u001b[31m";
const YELLOW = "\u001b[33m";
const DIM = "\u001b[2m";
const BOLD = "\u001b[1m";

const useColor = Boolean(process.stdout.isTTY) && !process.env.NO_COLOR;
const paint = (code, text) => (useColor ? `${code}${text}${RESET}` : text);

function formatDetail(detail) {
  if (detail === undefined || detail === null || detail === "") return "";
  if (typeof detail === "string") return detail;
  if (detail instanceof Error) return `${detail.message}`;
  try {
    return JSON.stringify(detail);
  } catch {
    return String(detail);
  }
}

function reportDir() {
  return process.env.KIT_REPORT_DIR
    ? resolve(process.env.KIT_REPORT_DIR)
    : resolve(process.cwd(), "reports");
}

/**
 * Crea una suite. Devuelve un objeto con la API de checks.
 * @param {string} name  nombre de la suite (sin espacios; se usa como nombre de archivo)
 * @param {{file?: string, quiet?: boolean}} [opts]
 */
export async function suite(name, opts = {}) {
  const file = toPath(opts.file);
  const quiet = Boolean(opts.quiet);
  const checks = [];
  const cleanups = [];
  const startedAt = Date.now();
  const rel = file ? relative(process.cwd(), resolve(file)) : "";
  let section = "";

  const push = (status, checkName, detail) => {
    const entry = {
      name: checkName,
      status,
      section,
      detail: formatDetail(detail),
      ms: 0,
    };
    checks.push(entry);
    if (!quiet) {
      if (status === "ok") console.log(`${paint(GREEN, "[OK]  ")} ${checkName}`);
      else if (status === "fail")
        console.log(`${paint(RED, "[FAIL]")} ${checkName}${entry.detail ? ` -> ${entry.detail}` : ""}`);
      else console.log(`${paint(YELLOW, "[SKIP]")} ${checkName}${entry.detail ? ` (${entry.detail})` : ""}`);
    }
    return status === "ok";
  };

  const api = {
    name,
    file,

    /** Cambia de bloque en la salida (para agrupar la lectura). */
    section(title) {
      section = title;
      if (!quiet) console.log(paint(DIM, `· ${title}`));
    },

    /** Afirmacion booleana. `detail` es lo que se imprime si falla. */
    check(checkName, cond, detail) {
      const ok = Boolean(cond);
      return push(ok ? "ok" : "fail", checkName, ok ? "" : detail);
    },

    /** Comparacion exacta (con normalizacion de `-0` y de objetos/arrays shallow). */
    equal(checkName, actual, expected) {
      const same = Object.is(actual, expected) || actual === expected;
      return push(
        same ? "ok" : "fail",
        checkName,
        same ? "" : `esperado ${formatDetail(expected)} | obtenido ${formatDetail(actual)}`
      );
    },

    /** Ejecuta un paso; una excepcion cuenta como falla (no como crash). */
    step(checkName, fn) {
      const t0 = Date.now();
      try {
        const result = fn();
        if (result && typeof result.then === "function") {
          return result.then(
            () => {
              checks[checks.length - 1] && (checks[checks.length - 1].ms = Date.now() - t0);
              return push("ok", checkName, "");
            },
            (err) => push("fail", checkName, err)
          );
        }
        checks[checks.length - 1] && (checks[checks.length - 1].ms = Date.now() - t0);
        return push("ok", checkName, "");
      } catch (err) {
        return push("fail", checkName, err);
      }
    },

    /** Documenta un limite conocido: no cuenta como falla. */
    skip(checkName, reason) {
      return push("skip", checkName, reason);
    },

    /** Nota informative (no cuenta). */
    note(message) {
      if (!quiet) console.log(paint(DIM, `  ${message}`));
    },

    /** Registra una limpieza (se corre al finish, en orden inverso, aunque haya fallas). */
    cleanup(fn) {
      cleanups.push(fn);
      return api;
    },

    /** Corre las limpiezas registradas. */
    async runCleanup() {
      for (const fn of cleanups.reverse()) {
        try {
          await fn();
        } catch (err) {
          if (!quiet) console.log(paint(YELLOW, `[WARN] limpieza fallo: ${formatDetail(err)}`));
        }
      }
      cleanups.length = 0;
    },

    /** Cierra la suite: limpieza + resumen + reporte JSON + exit code. */
    async finish() {
      await api.runCleanup();
      const ok = checks.filter((c) => c.status === "ok").length;
      const fail = checks.filter((c) => c.status === "fail").length;
      const skip = checks.filter((c) => c.status === "skip").length;
      const ms = Date.now() - startedAt;

      if (!quiet) {
        const color = fail > 0 ? RED : GREEN;
        console.log(
          paint(
            color,
            `RESULT ok=${ok} fail=${fail} skip=${skip} suite=${name}` +
              (rel ? ` file=${rel}` : "") +
              ` ms=${ms}`
          )
        );
      }

      try {
        const dir = reportDir();
        mkdirSync(dir, { recursive: true });
        writeFileSync(
          join(dir, `${name}.json`),
          JSON.stringify(
            { suite: name, file: rel, ok, fail, skip, ms, checks, startedAt },
            null,
            2
          ),
          "utf8"
        );
      } catch (err) {
        if (!quiet) console.log(paint(YELLOW, `[WARN] no se pudo escribir el reporte: ${formatDetail(err)}`));
      }

      if (fail > 0) process.exitCode = 1;
      return { ok, fail, skip, ms };
    },
  };

  if (!quiet) {
    console.log(paint(BOLD, `== ${name}${rel ? ` (${rel})` : ""}`));
  }
  return api;
}

/** Atajo para una bateria de una sola pasada. */
export async function run(name, fn) {
  const t = await suite(name, { file: import.meta.url });
  await fn(t);
  return t.finish();
}
