# Reparto a jugadores

Una vez que el sistema actualiza el rating del **equipo** tras un partido, hay que bajar ese resultado a cada **jugador**. El problema es que no todos contribuyeron igual: un crack en un equipo que perdió no merece comerse el mismo castigo que un pasajero, y al revés, alguien que casi no tocó la pelota en un equipo ganador no debería subir tanto.

## Cómo funciona

OpenSkill (Plackett-Luce) ya reparte de forma nativa el resultado de equipo a los individuos que lo componen. Sobre eso se afina con **partial-play weighting**: a cada jugador se le asigna un peso que modula cuánto del swing del equipo le toca. En el caso clásico ese peso representa el tiempo jugado (un suplente que entró 10 minutos absorbe menos resultado que un titular que jugó todo).

La idea de la tesis es no quedarse en el tiempo jugado, sino ponderar ese peso por la **contribución real derivada del tracking**: VAEP/EPV por jugador. Así el reparto deja de ser plano y refleja quién efectivamente movió la aguja del partido.

El efecto buscado:

- Un crack en un equipo que pierde, pierde menos rating.
- Un pasajero en un equipo que gana, gana menos rating.

## La fórmula

El partial-play entra como un peso por jugador que escala su porción del update:

```
peso_jugador = contribución_jugador (VAEP/EPV derivado del tracking)
```

Cómo se normalizan exactamente esos pesos dentro del equipo (y cómo se combinan con el tiempo jugado, si es que se combinan) queda **abierto**: en las fuentes el reparto se describe a nivel conceptual, no hay una calibración cerrada.

## Cómo se usa en Sportify

Es el tercero de los tres sub-problemas encadenados del rating: señal de dominancia del partido, update del rating de equipo, y este reparto a jugadores. Conecta el pipeline de visión/tracking con el rating individual: las contribuciones que salen del análisis de cada jugador alimentan los pesos de partial-play, y el resultado de equipo termina aterrizando en el rating de cada uno de forma justa.

**Fuente:** [../research/references.md](../research/references.md)
