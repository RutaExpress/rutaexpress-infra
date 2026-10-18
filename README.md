# rutaexpress-infra

Infraestructura del caso RutaExpress (DSY1107 Cloud Native I): **clúster RabbitMQ de 2 nodos** y, en la siguiente etapa, el compose de los microservicios para AWS.
Los Dockerfiles viven en cada microservicio; este repo solo tiene los compose y la configuración.

## Estructura
```
rutaexpress-infra/
├── mq/                          Clúster RabbitMQ (Guía 2.3.1)
│   ├── compose.yml              definitions (paso previo) + rabbitmq-1 + rabbitmq-2
│   ├── rabbitmq.conf            clustering classic_config + carga de definitions
│   ├── definitions.template.json  vhost rutaexpress, 4 usuarios y sus permisos (sin contraseñas)
│   ├── generar-definitions.sh   reemplaza cada contraseña por su hash SHA-256
│   └── .env.example             variables a completar (el .env real no se sube)
└── .github/workflows/ci.yml     valida los compose en cada PR
```

## Cómo funciona
1. `definitions` lee las contraseñas del `.env`, calcula su **hash** con `rabbitmqctl hash_password` y escribe `definitions.json` en un volumen. Termina con **Exited (0)**.
2. `rabbitmq-1` arranca, carga el `definitions.json` (vhost, usuarios, permisos).
3. `rabbitmq-2` arranca cuando el nodo 1 está sano y se une al clúster (misma **cookie de Erlang** + lista de nodos en `rabbitmq.conf`).

## Levantar en local
```
cd mq
copy .env.example .env        (Windows)   |   cp .env.example .env   (Linux)
# editar .env con contraseñas propias (solo letras y números)
docker compose up -d
docker compose ps -a
docker exec rabbitmq-1 rabbitmqctl cluster_status
```
- Consola nodo 1: http://localhost:15672 · nodo 2: http://localhost:15673 (usuario `rx-admin`)
- `guest` no existe: al cargar definitions solo quedan los usuarios definidos.

## Usuarios (vhost `rutaexpress`, mínimo privilegio)
| Usuario | Lo usa | Tag | configure / write / read |
|---|---|---|---|
| `rx-admin` | persona (consola) | administrator | todo / todo / todo |
| `rx-ops` | ms-rutaexpress-rabbit-admin | — | todo / todo / todo |
| `rx-shipments` | ms-rutaexpress-shipments (productor) | — | `cmd.*` / `cmd.*` / nada |
| `rx-notify` | ms-rutaexpress-notify (consumidor) | — | `cmd.*` y `q.cmd.*` en los tres |

## Conectar un microservicio al clúster
| Variable | Valor local | Valor en AWS |
|---|---|---|
| `RABBITMQ_ADDRESSES` | `localhost:5672,localhost:5673` | `<IP privada ec2-mq>:5672,<IP privada ec2-mq>:5673` |
| `RABBITMQ_USER` / `RABBITMQ_PASSWORD` | usuario `rx-*` del servicio | igual |
| `RABBITMQ_VHOST` | `rutaexpress` | `rutaexpress` |

## Bajar
- `docker compose down` → detiene (datos se conservan en los volúmenes)
- `docker compose down -v` → borra también los datos (clúster desde cero)

## Avance
| Paso | Descripción | Estado |
|---|---|---|
| F4-a | Clúster RabbitMQ 2 nodos + usuarios por definitions | ✅ |
| F4-b | `apps/compose.aws.yml` (microservicios + Oracle) | ⏳ |
