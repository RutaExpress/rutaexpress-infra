# rutaexpress-infra

Infraestructura del caso RutaExpress (DSY1107 Cloud Native I): **clúster RabbitMQ de 2 nodos** (`mq/`), **compose de los microservicios** (`apps/`) y la **plantilla CloudFormation** (`cloudformation/`) que crea todo en AWS.
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
├── cloudformation/
│   └── rutaexpress-stack.yaml   VPC, Security Groups, ec2-mq, ec2-apps (EIP), API Gateway + JWT + CORS
└── .github/workflows/ci.yml     valida los compose y la plantilla (cfn-lint) en cada PR
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

## Despliegue en AWS (`cloudformation/rutaexpress-stack.yaml`)
```
Internet ──► API Gateway (CORS + JWT Entra ID v2, 6 rutas) ──► ec2-apps :8082 BFF ──► shipments ──► Oracle
                                                                  │ AMQP por IP privada (SG: solo desde ec2-apps)
                                                                  ▼
                                                     ec2-mq: rabbitmq-1 + rabbitmq-2
```
| Qué crea | Detalle |
|---|---|
| Red | VPC 10.0.0.0/16, subred pública, Internet Gateway, rutas |
| Security Groups | apps: 443 y 8082 abiertos; 22 y 8085 solo `AdminCidr`. mq: 5672-5673 solo desde el SG de apps; 22 y 15672-15673 solo `AdminCidr` |
| ec2-mq | UserData: Docker → clona este repo → genera `mq/.env` desde parámetros NoEcho → `docker compose up -d` |
| ec2-apps + Elastic IP | UserData: Docker + swap 4 GB → clona los 5 repos con el token (y lo borra del remoto) → genera `apps/.env` con la IP privada de ec2-mq → build de a una → `up -d` |
| API Gateway HTTP | CORS (`https://<EIP>`, `http://localhost:4200`), authorizer JWT v2, stage `rutaexpress`, 6 rutas con su verbo |

| Verbo | Ruta | JWT |
|---|---|---|
| GET | /api/v1/public/status | no |
| GET | /api/v1/me | sí |
| GET | /api/v1/shipments | sí |
| POST | /api/v1/shipments | sí |
| GET | /api/v1/shipments/{id} | sí |
| PUT | /api/v1/shipments/{id}/status | sí |

Parámetros secretos (`NoEcho`): token de GitHub, cookie de Erlang, contraseñas `rx-*` y de Oracle. Nunca se escriben en el repo.
Progreso del arranque en cada EC2: `sudo tail -f /var/log/cloud-init-output.log` (termina con `RUTAEXPRESS ... LISTO`).

## Bajar
- `docker compose down` → detiene (los datos se conservan en los volúmenes)
- `docker compose down -v` → borra también los datos

## Avance
| Paso | Descripción | Estado |
|---|---|---|
| F4-a | Clúster RabbitMQ 2 nodos + usuarios por definitions | ✅ |
| F4-b | `apps/compose.aws.yml` (microservicios + Oracle) | ✅ |
| F5 | Plantilla CloudFormation `rutaexpress-stack.yaml` | ✅ |
