# Suavizado de trayectorias

El **jitter posicional** es el temblequeo cuadro a cuadro de la posición de un jugador: aunque el jugador esté quieto o moviéndose suave, la posición detectada salta unos centímetros para un lado y para el otro entre frames consecutivos. Es ruido de medición, no movimiento real.

En el medallón esto es la primera operación de limpieza de silver (la capa que lleva el dato crudo de bronze a algo conforme y servible): **reducir el jitter posicional cuadro a cuadro** antes de derivar nada. Importa que sea una etapa propia y auditable porque toda métrica de gold se calcula sobre silver, nunca sobre el crudo.

## Por qué hace falta con tracking amateur

El tracking amateur de Sportify sale de reconstruir posiciones desde video, no de chips ni de cámaras profesionales calibradas. Eso mete ruido posicional en cada frame. El problema es que la **velocidad se deriva** de posiciones consecutivas: si la posición tiembla, la velocidad derivada se dispara y se vuelve basura. Suavizar la trayectoria primero es lo que hace confiable todo lo que viene después (velocidad, y de ahí las métricas de estructura).

Como todavía no hay tracking amateur real, esto se valida degradando sintéticamente el tracking limpio de Metrica (inyectando ruido, huecos e ID-switches) y midiendo cuánto recupera silver contra la verdad limpia.

## Cómo funciona

La idea general es ajustar cada trayectoria a una curva suave que siga el movimiento real y descarte el temblequeo. Dos familias clásicas para esto:

- **Filtro de Kalman:** estima la posición real combinando la medición ruidosa con un modelo del movimiento (posición + velocidad esperadas). Pondera medición vs. predicción según cuánto confíe en cada una.
- **Savitzky-Golay:** ajusta un polinomio de grado bajo a una ventana deslizante de frames y se queda con el valor suavizado del centro. Es un suavizado local que preserva mejor la forma de los picos.

El algoritmo concreto que va a usar Sportify queda **abierto**: la spec de datos lista el suavizado como requisito (FR-S1) pero deja la implementación sin fijar (open item §7 #6). No hay fórmula comprometida en las fuentes todavía.

## Cómo se usa en Sportify

Suavizado es FR-S1, la primera de las ocho operaciones de silver. Corre sobre los frames de bronze antes de la interpolación de huecos, la remoción de outliers y la derivación de velocidades. Su error contra la verdad limpia de Metrica se mide por separado, como parte de la validación por degradación sintética.
