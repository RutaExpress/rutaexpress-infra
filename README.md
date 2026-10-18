# rutaexpress-infra

Infraestructura del caso RutaExpress (DSY1107 Cloud Native I): **clúster RabbitMQ de 2 nodos** (`mq/`) y **compose de los microservicios** (`apps/`) para AWS.
Los Dockerfiles viven en cada microservicio; este repo solo tiene los compose y la configuración.

## Estructura
```
rutaexpress-infra/
├── mq/                          Clúster RabbitMQ (Guía 2.3.1) → ec2-mq
│   ├── compose.yml              definitions (paso previo) + rabbitmq-1 + rabbitmq-2
│   ├── rabbitmq.conf            clustering classic_config + carga de definitions
│   ├── definitions.template.json  vhost rutaexpress, 4 usuarios y sus permisos (sin contraseñas)
│   ├── generar-definitions.sh   reemplaza cada contraseña por su hash SHA-256
│   └── .env.example             variables a completar (el .env real no se sube)
├── apps/                        Microservicios + Oracle → ec2-apps
│   ├── compose.aws.yml          oracle, shipments, bff, notify, rabbit-admin (build desde cada repo)
│   └── .env.example             MQ_HOST, contraseñas y carpetas de los repos
└── .github/workflows/ci.yml     valida los compose en cada PR
```

## Clúster RabbitMQ (`mq/`)
1. `definitions` lee las contraseñas del `.env`, calcula su **hash** con `rabbitmqctl hash_password` y escribe `definitions.json` en un volumen. Termina con **Exited (0)**.
2. `rabbitmq-1` arranca y carga el `definitions.json` (vhost, usuarios, permisos).
3. `rabbitmq-2` arranca cuando el nodo 1 está sano y se une al clúster (misma **cookie de Erlang** + lista de nodos en `rabbitmq.conf`).

```
cd mq
copy .env.example .env        (Windows)   |   cp .env.example .env   (Linux)
docker compose up -d
docker exec rabbitmq-1 rabbitmqctl cluster_status
```
- Consola nodo 1: http://localhost:15672 · nodo 2: http://localhost:15673 (usuario `rx-admin`)
- `guest` no existe: al cargar definitions solo quedan los usuarios definidos.

| Usuario | Lo usa | Tag | configure / write / read |
|---|---|---|---|
| `rx-admin` | persona (consola) | administrator | todo / todo / todo |
| `rx-ops` | ms-rutaexpress-rabbit-admin | — | todo / todo / todo |
| `rx-shipments` | ms-rutaexpress-shipments (productor) | — | `cmd.*` / `cmd.*` / nada |
| `rx-notify` | ms-rutaexpress-notify (consumidor) | — | `cmd.*` y `q.cmd.*` en los tres |

## Microservicios (`apps/`)
Cada servicio se construye con el **Dockerfile de su repo** (los repos se clonan al lado de `rutaexpress-infra`).
```
cd apps
copy .env.example .env        (completar; las contraseñas rx-* iguales a mq/.env)
docker compose -f compose.aws.yml up -d --build
docker compose -f compose.aws.yml ps
```
| Servicio | Puerto | Quién lo usa | Usuario RabbitMQ |
|---|---|---|---|
| oracle | — (solo red interna) | shipments (`oracle:1521/ORCLPDB1`) | — |
| shipments | `127.0.0.1:8081` (solo la propia máquina) | bff (`http://shipments:8081`) | rx-shipments |
| bff | `8082` | API Gateway / front | — |
| notify | — (no expone HTTP) | consume colas | rx-notify |
| rabbit-admin | `8085` (en AWS solo IP del admin) | operación | rx-ops |

- `MQ_HOST`: `host.docker.internal` en local; **IP privada de ec2-mq** en AWS.
- Simulador de fallas: `NOTIFY_SMTP_FAIL_FIRST=2` (reintentos que se recuperan) o `=3` (termina en DLQ); se aplica recreando solo notify.

## Bajar
- `docker compose down` → detiene (los datos se conservan en los volúmenes)
- `docker compose down -v` → borra también los datos

## Avance
| Paso | Descripción | Estado |
|---|---|---|
| F4-a | Clúster RabbitMQ 2 nodos + usuarios por definitions | ✅ |
| F4-b | `apps/compose.aws.yml` (microservicios + Oracle) | 🔄 |
