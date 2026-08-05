# Workers (Python)

Los **workers** son los procesos Python que hacen el laburo pesado offline: corren el **medallón** (bronze→silver→gold) y el **update del rating**, un partido a la vez. Escriben sus resultados al store y nunca exponen API: la app móvil no los toca, solo habla con el backend Go.

## Qué son

Un único pipeline Python, modular por etapa: `bronze`, `silver`, `gold` y `rating`. No es un servicio que atiende requests; es un proceso que consume trabajo encolado y procesa. Va separado del backend Go porque acá vive el stack analítico (kloppy, socceraction y compañía) que en Go no tendría sentido reescribir.

## Cómo funciona

El flujo es siempre en una dirección y se coordina **a través del store**, sin que Go y Python se llamen por red:

```
backend_go --> mongo.jobs          # Go encola el partido a procesar
workers_py <-- mongo.jobs          # el worker lo consume
workers_py --> parquet (bronze/silver)   # crudo + limpio en archivos
workers_py --> mongo (gold)              # lo servible va a la base
```

- **Bronze/silver/gold:** el `reconstruction.json` del upstream entra a bronze tal cual, silver lo limpia al `Frame` canónico, y gold deja lo servible (métricas, dominancia, contribución por jugador). Bronze y silver se persisten como **parquet**; solo gold va a MongoDB.
- **Rating:** la etapa final hace el update del rating con el resultado del partido. El update es atómico a nivel del documento `user`.
- Es **idempotente**: se puede reprocesar el medallón desde bronze sin molestar al upstream y obtener el mismo gold.

Cuando el worker termina, no avisa a Go por red: escribe al store y Go observa el cambio (vía change streams de Mongo). El mecanismo exacto de coordinación job/notificación queda **abierto**.

## Cómo se usa en Sportify

Es la mitad offline de la plataforma. Go resuelve lo on-demand (emparejamiento, servir leaderboard/perfil/reporte); los workers procesan cada partido cuando hay tracking nuevo y dejan el `scoring.json` y el rating actualizado listos para que Go los sirva. El esquema exacto de `scoring.json` y el detalle de observabilidad (qué se loguea por etapa) quedan **abiertos**.
