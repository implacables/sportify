# Especificación — Contratos

Las interfaces de datos entre sistemas. La calidad de scoring depende de estos contratos.

---

## Entrada — `reconstruction.json` (de la reconstrucción)

Serie temporal per-frame que produce el pipeline de Valentín ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5). Por cada muestra: `frame_index`, `timestamp_ms`, y `players[]` con `user_id`, `x`, `y`, `z`, `confidence` (en metros, sobre la cancha).

**Lo que necesitamos que agregue (2 gaps):**

| Gap | Por qué |
|-----|---------|
| **Posición de la pelota** por frame | sin pelota no hay SPADL, ni valor on-ball (xT/VAEP), ni término de transición de OBSO. |
| **Jugadores no-identificados** con posición | las métricas de equipo (centroide, hull, pitch control) necesitan los 11, aunque no estén identificados individualmente. |

> La **dirección de ataque** NO se pide al contrato (no es confiable determinarla; las métricas robustas son direction-agnostic). Las **dimensiones del venue** se necesitan para normalizar a metros y viven en el `job.meta.json`.

## Salida — `scoring.json` (hacia matchmaking y app)

Artefacto que produce la rama de analytics. **A definir** — debe incluir, como mínimo: score de dominancia del partido + contribución por jugador. Es el insumo del rating y del reporte que muestra la app.

> 🟡 Abierto: definir el esquema exacto de salida.
