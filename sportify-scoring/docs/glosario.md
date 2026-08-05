# Glosario

Términos que se usan en todo el sistema.

| Término | Qué es |
|---------|--------|
| **Reconstrucción (game state reconstruction)** | Convertir el video del partido en posiciones e identidades de jugadores por frame. Es el sistema upstream (de Valentín). |
| **Tracking** | La serie de posiciones de jugadores y pelota a lo largo del tiempo. |
| **Frame** | Una muestra del estado del juego en un instante: posiciones + pelota + timestamp. |
| **Medallón (bronze/silver/gold)** | Las tres capas de calidad del dato: crudo → limpio → features. |
| **Silver / limpieza** | La etapa que convierte el tracking ruidoso en uno confiable (suavizado, IDs, velocidades). |
| **Pitch control** | Campo de probabilidad de qué equipo controla cada zona de la cancha. |
| **OBSO** | Off-Ball Scoring Opportunity: peligro de gol del espacio ocupado sin la pelota. |
| **EPV** | Expected Possession Value: valor esperado de una posesión; framework modular e interpretable. |
| **SPADL** | Formato estándar de acciones on-ball (pases, tiros…), que derivamos del tracking. |
| **Dominancia** | Score que mide cuánto mereció ganar un equipo, derivado de analytics (no de goles). |
| **OpenSkill** | Motor de rating multi-equipo (Plackett-Luce) elegido para el matchmaking. |
| **El puente** | Alimentar el margen del rating con la dominancia en vez de la diferencia de goles. La contribución original de la tesis. |
| **Venue** | La cancha/instalación: define dimensiones y homografía (calibración). |
| **Identidad invitado** | Jugador detectado sin cuenta; rating "en la sombra" reclamable al registrarse. |
