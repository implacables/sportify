# Monolito modular

Un monolito modular es un único deployable cuyo código está partido por adentro en módulos de frontera dura: cada módulo es dueño de sus datos, se expone por interfaz, y no toca lo que es de otro. No son microservicios (no hay red entre módulos, no hay deploy separado), pero las fronteras están dibujadas como si lo fueran, así extraer un módulo a servicio después es mover código, no reescribir su contrato.

En Sportify son dos piezas, cada una modular por adentro:

- **Backend Go** — un solo servicio, binario único, modular por dominio: `identidad`, `partidos`, `ratings`, `matchmaking`, `analytics`. Es la única superficie pública: la app móvil habla solo con él.
- **Pipeline Python** — un solo pipeline, modular por etapa del medallón: `bronze`, `silver`, `gold`, `rating`. Procesa el tracking; no expone API a la app.

La disciplina de fronteras es la regla que sostiene todo:

```
- Cada módulo es dueño de sus datos; nadie lee/escribe la colección de otro módulo.
- Los módulos se hablan por interfaz, no por la base compartida.
- Go y Python no se llaman por red: se coordinan a través del store (Mongo + parquet).
- Tocar la colección de otro módulo = violación de arquitectura.
```

Esto es lo que mantiene el sistema "divisible después" (microservices-ready) sin pagar el costo de microservicios ahora: empezás chico y desplegable en un VPS, pero ya con las costuras por donde después se corta. El emparejamiento on-demand resuelve en Go; el update del rating, en el worker Python; ninguno invade al otro.

Qué queda **abierto**: portar a Go piezas estables del worker (geometría, rating) más adelante, manteniendo VAEP/xT en Python, es una decisión diferida.
