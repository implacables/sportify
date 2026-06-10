# El puente (la tesis)

El **puente** es la idea central de la tesis: que el `margin` que escala el swing del rating se alimente de la **dominancia derivada de analytics**, y no de la diferencia de goles.

## Qué es

En un motor de rating, el `margin` es la magnitud del resultado que se usa para escalar cuánto se mueve el rating de cada equipo tras un partido (el swing). Lo habitual es alimentarlo con la diferencia de goles. El problema: en fútbol amateur el marcador es **ruidoso** — un 3-0 puede salir de un par de jugadas con suerte y no reflejar quién jugó mejor.

El puente reemplaza esa señal por un **score de dominancia** derivado del tracking: cuánto **mereció** ganar cada equipo, medido sobre espacio y peligro generado, no sobre goles convertidos.

## Cómo funciona

La dominancia se compone de señales de analytics (Rama B), combinadas con pesos calibrados empíricamente:

```
dominancia = w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + w4·Δfield_tilt
```

Esa dominancia entra al motor de rating como `margin`. El efecto: un equipo que dominó espacio y peligro sube fuerte aunque gane 1-0; un 3-0 con suerte no infla tanto el rating. Dos partidos con la misma diferencia de goles pero distinta dominancia producen swings distintos.

El cómputo de la dominancia y la calibración de los pesos `w1..w4` viven en analytics, no acá: al puente la dominancia le entra ya computada vía `scoring.json`.

## Cómo se usa en Sportify

El motor de rating (OpenSkill / Plackett-Luce) acepta un `margin` como entrada. La rama de rating arranca funcionando con un **margen simple** (diferencia de goles del árbitro o señal binaria victoria/empate/derrota) desde el día 1, sin depender de analytics. Cuando analytics está disponible, ese `margin` pasa a alimentarse con la dominancia de `scoring.json`.

El cambio de fuente (simple → dominancia) **no** reescribe el motor ni el esquema del rating: solo cambia el valor de entrada `margin`. Por update se registra qué fuente se usó, para trazabilidad de tesis.

## Por qué es la contribución original

Cerrar el lazo entre el análisis de video y el rating sustituyendo el marcador por una señal de mérito es lo que distingue a la tesis del rating deportivo estándar. El motor (OpenSkill), la predicción `P(A gana)` y el reparto por partial-play son maquinaria conocida; lo original es **de dónde sale el margen**.

Abierto: la normalización de la dominancia al `margin` que espera el motor (escala, mapeo, clipping) y si OpenSkill necesita una corrección de autocorrelación equivalente al `corr` de Elo-MOV para que el margen no infle el sistema.

**Fuente:** [referencias](../research/references.md)
