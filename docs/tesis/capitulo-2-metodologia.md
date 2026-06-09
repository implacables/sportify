**CAPÍTULO 2**

# **Introducción**

Este capítulo presenta la metodología adoptada para desarrollar el proyecto Sportify. Combina la **metodología de la investigación** —el recorrido sistemático desde el planteo del problema hasta las conclusiones— con la **metodología de gestión de proyectos** —las dimensiones que se administran a lo largo del trabajo—. El objetivo es dejar explícito *cómo* se va a abordar y conducir el proyecto antes de su desarrollo.

# **Tipo de investigación**

La investigación es de tipo **aplicada**: se orienta a resolver un problema concreto del sector —la organización y el emparejamiento en el fútbol amateur. El **diseño es experimental**: se construye un sistema y se lo somete a mediciones en condiciones controladas (throughput de reconstrucción, validez de las métricas, calidad del emparejamiento) para observar los resultados que produce.

# **Objetivos, Hipótesis y Propósito**

## **Objetivo General**

Demostrar la viabilidad técnica de una plataforma para fútbol amateur que:

- reconstruya el estado de juego a partir del video de forma significativamente más eficiente que el baseline SoccerNet GSR (sub 36hs) para fines de diciembre.
- Derive de ese tracking métricas objetivas y un score de dominancia que alimenten un sistema de emparejamiento justo.

## **Objetivos Específicos**

1. Implementar un pipeline de reconstrucción cuyo throughput supere al baseline SoccerNet GSR (~1,1 FPS end-to-end, sub 36hs).
2. Derivar, a partir del tracking, métricas espaciales y un score de dominancia del rendimiento de cada equipo.
3. Construir un sistema de rating y emparejamiento alimentado por esa analítica (no solo por el resultado).
4. Resolver la asociación de identidad jugador↔usuario de forma confiable.

## **Hipótesis**

Es posible reconstruir el estado de juego de partidos de fútbol amateur de manera significativamente más rápida que el baseline SoccerNet GSR y, a partir de ese tracking, derivar métricas objetivas y un score de dominancia que permitan emparejar jugadores y equipos de forma más justa que la evaluación subjetiva y manual actual.

## **Propósito**

Creación de una aplicación: la plataforma Sportify, desarrollada como prueba de concepto.

# **Metodología de la Investigación**

Se sigue el recorrido sistemático del área temática a las conclusiones, instanciado en el proyecto.

## **Área temática**

Visión por computadora aplicada al deporte: reconstrucción del estado de juego, analítica posicional y emparejamiento en fútbol amateur.

## **Planteamiento del problema**

En el fútbol amateur la evaluación de nivel y la organización de partidos dependen de conocimiento informal y subjetivo, que no escala y deja sin referencia a los jugadores nuevos. No existe una forma objetiva y automática de medir el nivel desde el juego real, y los pipelines de reconstrucción existentes (~1,1 FPS, ~36 h por partido) son demasiado lentos y costosos para ser viables a escala amateur.

## **Delimitación**

POC sobre fútbol amateur, en VPS, con tres subsistemas mínimos (reconstrucción, analítica, emparejamiento). Fuera de alcance: nube gestionada a escala y precisión nivel broadcast.

## **Marco teórico**

Game State Reconstruction (SoccerNet); modelos de tracking; superficies de valor (pitch control, OBSO, EPV); métricas de compactación; sistemas de rating (OpenSkill, Glicko-2, Elo con margen). Se desarrolla en el Capítulo 3.

## **Diseño concreto**

Diseño experimental: construir el sistema y medir su throughput contra el baseline, validar la analítica contra implementaciones de referencia y con degradación sintética, y validar el emparejamiento con simulaciones.

## **Operacionalización (indicadores)**

Reconstrucción: throughput efectivo (FPS). Analítica: validez de las métricas a través de análisis humano y robustez (con ruido). Emparejamiento: convergencia del rating y balance de los partidos. Identidad: tasa de asociación correcta jugador↔usuario.

## **Técnicas de recolección**

Corridas de benchmark sobre datasets (SoccerNet-GS); simulaciones de emparejamiento; footage amateur propio.

## **Instrumentos**

Harness de benchmark (FPS, pasos condicionales); notebooks de análisis; scripts de evaluación; esquema de resultados; cuestionarios a jugadores y entrevistas a organizadores.

## **Datos**

Reconstrucción de partido: dataset público SoccerNet-GS. Analítica: datasets de Kaggle, datos sintetizados y resultados tempranos de la reconstrucción.

## **Síntesis y conclusiones**

Determinar si el sistema demuestra la hipótesis: reconstrucción más eficiente, analítica útil y emparejamiento objetivo.

# **Metodología de Gestión de Proyectos**

El proyecto se administra sobre siete dimensiones.

## **Alcance**

POC con tres subsistemas integrados (reconstrucción, analítica, emparejamiento); la reconstrucción debe superar el throughput de SoccerNet. Excluye nube gestionada y precisión broadcast.

## **Tiempos**

Metodología lean.

## **Costos**

VPS con GPU rentada, almacenamiento y suscripciones a agentes de IA (a calcular).

## **Riesgos**

Que la reconstrucción no sea lo bastante rápida; que el emparejamiento no cumpla expectativas; que la identidad no sea confiable; el cronograma; la calidad del tracking amateur.

## **Calidad**

Por subsistema (throughput vs baseline; validez y robustez de las métricas; convergencia y balance del emparejamiento).

## **Recursos**

Equipo (analítica/matchmaking + reconstrucción + tutores), infraestructura (VPS/GPU), stack (Go/Python/MongoDB + agentes de IA) y datos abiertos.

## **Satisfacción**

El valor diferencial: emparejar usando visión por computadora —medir el skill desde el juego real— en lugar de la evaluación subjetiva.
