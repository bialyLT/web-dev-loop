/**
 * Bateria de ejemplo: sirve de smoke test del kit.
 *   node tools/example/demo-battery.mjs               -> RESULT ok=4 fail=0 skip=1 (exit 0)
 *   DEMO_FAIL=1 node tools/example/demo-battery.mjs   -> muestra una falla (exit 1)
 */

import { suite } from "../harness.mjs";

const t = await suite("demo-kit", { file: import.meta.url });

t.section("harness");
t.check("la API expone check/equal/step/skip", ["check", "equal", "step", "skip"].every((m) => typeof t[m] === "function"));
t.equal("la aritmetica funciona", 2 + 2, 4);

t.section("ejemplo de falla (informativa)");
if (process.env.DEMO_FAIL === "1") {
  t.check("esto falla a proposito", false, "es una demostracion del formato de salida");
} else {
  t.check("todo verde en el modo normal", true);
}

t.section("ejemplo de limite conocido");
t.skip("requiere un navegador real", "esta bateria no abre nada");

await t.finish();
