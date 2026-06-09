# Sportify — Research consolidada: analytics + team rating + matchmaking

> **Estado:** versión consolidada en el repo (fuente de verdad de la research).
> Origen: deep-research harness del 2026-05-28 (107 agentes, 25 fuentes, 96 claims, 24 verificadas 3-0 adversarial) + síntesis dirigida de fórmulas. Borrador de trabajo en `_research-notes/` (local).
> Bibliografía completa con papers y links: [references.md](references.md).

---

## Resumen ejecutivo

Para un sistema de analytics post-tracking + rating de equipo + matchmaking, la evidencia converge en un blueprint claro:

1. **Estructura de datos:** dos modelos complementarios — tracking por-frame (kloppy `TrackingDataset`/`Frame`) para análisis espacial continuo + acciones on-ball (SPADL / Atomic-SPADL) para valor por acción, sincronizados por índice de frame/tiempo compartido.
2. **Superficie de métricas:** superficies de valor continuas (pitch control, Wide Open Spaces, OBSO) + frameworks de valor de posesión (xT, VAEP/Atomic-VAEP, EPV deep-learning).
3. **Rating equipo vs rival:** las mismas primitivas (pitch control, compactación, line-breaking, presión, valor de posesión) sobre frame normalizado.
4. **Sistema de primer nivel:** patrón EPV — modular, descompuesto, interpretable, sobre el estado espacio-temporal completo (22 + pelota).
5. **Matchmaking con margen:** OpenSkill (Plackett-Luce) + señal de dominancia derivada de analytics + reparto a individuos por contribución.

---

## (1) Estructura de datos para sacar analytics del tracking [VERIFICADO 3-0]

**Dos modelos complementarios, no uno:**

- **Tracking por-frame** — `kloppy.TrackingDataset` → `Frame`. Cada frame:
  `timestamp` + `ball_coordinates: Point3D` + `players_data: dict[Player → PlayerData]` (coordenadas por jugador). Para análisis espacial continuo.
- **Acciones on-ball** — **SPADL** (socceraction): tupla de **12 atributos** `(game_id, period_id, seconds, player, team, start_x, start_y, end_x, end_y, action_type, result, bodypart)`. **Atomic-SPADL**: 11 atributos (saca `result`, agrega desplazamiento `dx, dy`). Para valor por acción. ESTO LO DERIVAMOS internamente, no lo recibimos.
- **Sincronización** por índice frame/tiempo compartido → cualquier evento derivado se une al estado posicional completo (22 + pelota) en ese instante. Mecanismo central.
- **Coordenadas normalizadas canónicas** como prerrequisito:
  - SPADL: cancha 105×68m, origen abajo-izquierda, local ataca a la derecha, `play_left_to_right()`.
  - Metrica: normalizado `[0,1]`, (0,0) arriba-izq, (1,1) abajo-der, (0.5,0.5) saque.
  - kloppy: modelo vendor-independiente para event + tracking.
- **[REFUTADA 1-2]** NO hace falta convertir a metros 105×68 antes de calcular métricas espaciales — con `[0,1]` ya salen muchas. Convertir a metros solo para distancias/velocidades físicas reales.

**Pregunta abierta:** kloppy/SPADL son in-memory; falta definir capa de persistencia (datastore/feature-store, parquet) para superficies por-frame y métricas agregadas a escala.

Fuentes: kloppy.pysport.org (data-model, tracking) · socceraction.readthedocs.io (spadl, atomic_spadl) · github.com/ML-KULeuven/socceraction · github.com/metrica-sports/sample-data

---

## (2) Superficie máxima de analytics (de posiciones + pelota) [VERIFICADO 3-0]

Clave: **superficies de valor continuas** sobre toda la cancha, cada instante.

- **Pitch Control** — campo de probabilidad `[0,1]` de qué equipo controla cada zona. Cada jugador = proceso de Poisson con tasa `λ` = inverso del tiempo medio para hacer un toque controlado, integrado en el tiempo. = prob de que un equipo gane/retenga posesión si la pelota va a esa zona. Implementación de referencia: Friends of Tracking / LaurieOnTracking (modelo de Spearman), `calculate_pitch_control_at_target`.
- **Wide Open Spaces** (Fernández & Bornn, MIT Sloan) — valor de espacio creado/ocupado, a nivel **equipo y jugador individual, con y sin pelota**. Basado en pitch control desde modelo de prob de recepción.
- **OBSO** (Off-Ball Scoring Opportunity — Spearman "Beyond Expected Goals", MIT Sloan 2018) — modelo físico-probabilístico sobre tracking crudo: prob posterior de marcar en el próximo evento on-ball en cada zona. Descomposición: `control × transición × score` (pitch control × dónde va la pelota × prob de gol desde esa zona). Mide peligro del espacio ocupado SIN pelota.
- **Frameworks de valor de posesión** (socceraction): **xT** (Expected Threat), **VAEP / Atomic-VAEP**. Convierten event streams (StatsBomb/Opta/Wyscout/Stats Perform/WhoScored) a SPADL primero.

Fuentes: sloansportsconference.com (beyond-expected-goals, wide-open-spaces) · github.com/Friends-of-Tracking-Data-FoTD · github.com/ML-KULeuven/socceraction

---

## (3) Ratear rendimiento de equipo vs rival — FÓRMULAS [síntesis dirigida]

Las primitivas (topic 2) se construyen sobre el frame normalizado. Fórmulas concretas:

### Estructura / compactación (directo del frame, sin pelota — robusto a ruido)
```
centroide      = media(x, y) de los 10 de campo
stretch_index  = media de distancia euclídea de cada jugador al centroide
length         = max_x − min_x   (en dirección de ataque)
width          = max_y − min_y
LpW_ratio      = length / width
surface_area   = área del convex hull del equipo
team_spread    = media de la matriz de distancias entre todos los pares
EPS            = convex hull de AMBOS equipos (espacio efectivo de juego)
```
Bloque defensivo compacto = surface_area chica + length corta.

### Presión — PPDA
```
PPDA = pases_completados_del_rival / acciones_defensivas_propias
       (ambos en el 60% de cancha lejos del arco propio)
acciones_defensivas = tackles + intercepciones + faltas (+ presiones)
```
Interpretación: 4–8 presión alta · 9–12 bloque medio · 13+ bloque bajo.
⚠️ Requiere derivar "pase" y "acción defensiva" del tracking (capa de eventos interna).

### Romper líneas — Line-Breaking Passes (LBP) & Packing
- **LBP**: pase completado que (a) acerca la pelota ≥10% hacia el arco rival Y (b) cruza un par de defensores cercanos o pasa por detrás de la línea. Detección: clustering de líneas de defensores + chequear si el pase las atraviesa.
- **Packing**: nº de oponentes superados (pasan de delante a detrás de la pelota) por pase/conducción. `packing_rate = oponentes_superados / pases`. Ponderar más a defensores cerca del arco.

⚠️ LBP/Packing/PPDA dependen de la capa de eventos derivados → confirma que sincronizar evento-derivado ↔ frame es central.

Fuentes: the-footballanalyst.com (ppda, packing-rate) · arxiv.org/html/2506.06666v1 (LBP clustering) · nature.com/articles/s41598-025-97765-y · pmc.ncbi.nlm.nih.gov/articles/PMC8805357 (compactación, review)

---

## (4) Qué hace a un sistema de primer nivel [VERIFICADO 3-0]

Patrón **EPV** ("Decomposing the Immeasurable Sport", Fernández-Bornn-Cervone, MIT Sloan):
- Opera sobre el **estado espacio-temporal completo** (22 jugadores + pelota).
- **Descompone** en modelos componentes separados e interpretables (pase / conducción / tiro / pérdida), cada uno capturando táctica espacio-temporal.
- Los **fusiona** con un proceso estocástico de alto nivel.
- Descomposición = **interpretabilidad**: inspeccionar valor potencial de cada pase/conducción/tiro a cualquier zona.
- Combinar EPV + pitch control → mejores opciones de pase.

→ Lección de arquitectura Sportify: **modular, descompuesto, interpretable** (= scaffold hexagonal).

Otros proveedores relevados: StatsBomb/Hudl (360, possession value), SkillCorner (broadcast tracking, off-ball runs), Second Spectrum/Genius, PFF FC, Impect (packing), Opta/Stats Perform, Metrica.

Fuentes: sloansportsconference.com (decomposing-the-immeasurable-sport) · github.com/Friends-of-Tracking-Data-FoTD · skillcorner.com/blog/off-ball-runs · statsbomb.com (360)

---

## (5) Matchmaking + rating con margen de victoria [síntesis dirigida]

### Tres sub-problemas encadenados
1. **Señal de dominancia** del partido (¿goles? ¿analytics?)
2. **Update del rating de equipo** (cómo el margen escala el swing)
3. **Reparto a jugadores individuales**

### Capa 2 — margen escalando el swing

**Opción A — Elo con multiplicador de margen (FiveThirtyEight):**
```
E_win = 1 / (1 + 10^(-Δ/400))                     # prob esperada
mult  = ln(|MOV| + 1)                              # multiplicador por margen (rinde decreciente)
corr  = 2.2 / ((Elo_win − Elo_los)·0.001 + 2.2)    # corrección de autocorrelación
nuevo = viejo + K · mult · corr · (S − E_win)
```
`corr` es la pieza no-obvia: sin ella el margen INFLA el sistema. Achica el update cuando el favorito gana por mucho, lo agranda en upsets. Cumple "goleada = más gana/más pierde" anclado a expectativas (justo).
(Variante World Football Elo: índice de gol G=1 empate/1gol; 1.5 si 2; (11+N)/8 si N≥3.)

**Opción B — Bayesiano (RECOMENDADO):**
- **Glicko-2**: rating + RD (incertidumbre) + volatilidad σ, constante τ (0.3–1.2; chico=estable). RD crece con inactividad → ideal amateur esporádico. Pero es 1v1 puro.
- **OpenSkill (Plackett-Luce, Weng-Lin 2011)**: nativo **multi-equipo/multi-jugador**, open source, acepta parámetro `scores`/`margin` que mete el margen directo. Rating **vector multidimensional** (calza con perfiles FIFA por facetas). Conservador = `μ − 3σ`. Prob: `P(A gana) = 1/(1 + Σ exp(μ_B − μ_A))`.

→ **RECOMENDACIÓN: OpenSkill (Plackett-Luce)** como motor base. Resuelve sub-problemas 2 y 3 (equipos + margen + reparto vía partial-play). Glicko-2 como referencia para incertidumbre/inactividad.

### Sub-problema 1 — CONTRIBUCIÓN ORIGINAL de la tesis
En vez de alimentar el margen con **diferencia de goles** (ruidosa en amateur), alimentar con **score de dominancia derivado de analytics**:
```
dominancia = w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + w4·Δfield_tilt
```
Un equipo que MERECIÓ ganar (dominó espacio/peligro) sube fuerte aunque sea 1-0; un 3-0 con suerte no infla tanto. **Este es el puente analytics ↔ matchmaking** — novel y justificable.

### Capa 3 — reparto a jugadores
OpenSkill/TrueSkill reparten resultado de equipo a individuos. Afinar con **partial-play weighting** ponderado por **contribución derivada del tracking** (VAEP/EPV por jugador): crack en equipo que pierde → pierde menos; pasajero en equipo que gana → gana menos.

Fuentes: andr3w321.com/elo-ratings-part-2-margin-of-victory-adjustments · arxiv.org/html/2401.05451v1 (OpenSkill) · glicko.net/glicko/glicko2.pdf · sciencedirect.com/S0169207020300157 · arxiv 2010.11187

---

## Tabla resumen — decisiones para Sportify

| Capa | Decisión sugerida | Robustez tracking amateur |
|---|---|---|
| Estructura/compactación | Directo del frame (convex hull, stretch, length/width) | 🟢 Alta |
| Pitch control / espacio | Modelo Spearman/Fernández (posiciones+velocidad) | 🟡 Media |
| PPDA / packing / LBP | Capa de eventos derivados internos | 🟡 Media |
| Dominancia → margen | Score compuesto (ΔxG, Δpitch-control, ΔEPV) | 🟡 Media |
| Rating | OpenSkill Plackett-Luce + margen + reparto por contribución | 🟢 Alta |

---

## Preguntas abiertas (del harness + síntesis)
1. Capa de persistencia / schema de datastore (kloppy/SPADL son in-memory).
2. Robustez de pitch-control/OBSO/EPV con tracking amateur parcial/ruidoso — ¿calidad mínima?
3. Pesos `w1..w4` del score de dominancia — calibrar empíricamente.
4. Cold-start / convergencia del rating con pocos partidos amateur.

## Drift de URLs detectado
- Docs socceraction movidas a `/documentation/spadl/` (spadl.html, atomic_spadl.html); contenido idéntico (v1.5.3 dic-2024).
- Algunas páginas Sloan intermitentes (404/block) pero papers reales y corroborados.
