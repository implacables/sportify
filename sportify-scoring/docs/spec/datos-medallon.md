# Especificación — Datos (medallón)

Tres **estados del mismo dato** (capas lógicas, no infraestructura de lakehouse). La limpieza (silver) es una etapa propia **antes** de cualquier métrica.

---

| Capa | Qué es | Contenido | Persistencia |
|------|--------|-----------|--------------|
| 🥉 **Bronze** | crudo, inmutable | `reconstruction.json` tal cual + datos del árbitro. Posiciones crudas, IDs parciales, ruido, huecos. | parquet (archivos) |
| 🥈 **Silver** | limpio y conforme | suavizado de trayectorias, interpolación de oclusiones, continuidad de IDs, remoción de outliers, normalización a metros-venue, **derivación de velocidades**, asignación de equipo, validación de calidad. | parquet (archivos) |
| 🥇 **Gold** | features listas | métricas espaciales, superficies de valor, dominancia, agregados por partido/jugador/equipo. | MongoDB (lo servible) |

## Modelo `Frame` (canónico)

`timestamp` + `ball` (Point3D) + `players[]` (cada uno: posición en **metros del venue**, equipo, id, velocidad derivada). Agnóstico al `frame_stride` (no asume 25 fps).

## Validación de la limpieza

No hay tracking amateur real todavía → se **degrada** tracking limpio (Metrica) a calidad amateur de forma sintética (ruido, huecos, ID-switches) y se verifica que silver lo recupera.

Ver la fundamentación en [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md).
