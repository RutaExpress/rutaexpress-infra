# rutaexpress-infra

**Infraestructura** del caso RutaExpress: los compose de cada máquina (RabbitMQ, Kafka y microservicios), la colección de Postman y la plantilla **CloudFormation** que crea todo en AWS. Los Dockerfile viven en cada microservicio.

## Tecnologías
Docker Compose · RabbitMQ 4.2 (clúster de 2 nodos) · Kafka 3.6 con Zookeeper (3 + 3) · Oracle Free 23 · AWS CloudFormation · API Gateway HTTP · Microsoft Entra ID (JWT)

## Estructura
Un compose por máquina, como pide el caso.

```
rutaexpress-infra/
├── mq/               ec2-mq: rabbitmq-1 + rabbitmq-2 y usuarios rx-* (definitions)
├── kafka/            ec2-kafka: 3 Zookeeper + 3 brokers + Kafka UI; crea los 4 tópicos
├── apps/             ec2-apps: Oracle (un usuario por servicio), 9 microservicios y el front
├── cloudformation/   rutaexpress-stack.yaml: red, 3 EC2, Security Groups y API Gateway
└── postman/          Colección «Ruta Express»: pruebas P1 a P15
```
Cada carpeta trae su `.env.example`: se copia como `.env` y se completa. El `.env` no se sube.

## Arquitectura en AWS
```
Navegador ──► Front https://<IP elástica>
                 │
                 ▼
            API Gateway (CORS + JWT de Entra ID, 12 rutas) ──► ec2-apps :8082 BFF ──► microservicios ──► Oracle
                                                                    │ IP privada            │ IP privada
                                                                    ▼                       ▼
                                                     ec2-mq (RabbitMQ 2 nodos)   ec2-kafka (3 brokers)
```

| Máquina | Corre | IP pública |
|---|---|---|
| ec2-apps (t3.large) | Oracle, shipments, bff, notify, catalog, report, audit, kafka-admin, rabbit-admin y front | **Elástica (fija)** |
| ec2-mq (t3.small) | rabbitmq-1 y rabbitmq-2 | Cambia al reiniciar el laboratorio |
| ec2-kafka (t3.medium) | 3 Zookeeper, 3 brokers y Kafka UI | Cambia al reiniciar el laboratorio |

## Puertos
| Puerto | Qué | Abierto para |
|---|---|---|
| 443 | Front (HTTPS autofirmado) | Todos |
| 8082 | BFF (lo llama el API Gateway) | Todos (valida JWT y rol) |
| 8085 · 8088 | rabbit-admin · kafka-admin (sin login) | Todos (decisión de laboratorio) |
| 15672 · 15673 | Consola RabbitMQ (`rx-admin`) | Todos |
| 8080 | Kafka UI (`admin`) | Todos |
| 22 | SSH (`labsuser.pem` o EC2 Instance Connect) | Todos |
| 5672-5673 · 9092-9094 | AMQP · brokers de Kafka | **Solo desde ec2-apps** |

## Despliegue
1. CloudFormation → Crear pila → subir `cloudformation/rutaexpress-stack.yaml`.
2. Completar los parámetros secretos (token de GitHub de solo lectura, cookie de Erlang y contraseñas; solo letras y números).
3. Esperar el arranque de cada EC2: `sudo tail -f /var/log/cloud-init-output.log` (termina en `RUTAEXPRESS ... LISTO`).
4. En Entra ID → App registration → Authentication → SPA, agregar la salida `AzureRedirectUri` (`https://<IP elástica>`).

Las EC2 clonan la rama **`main`** de cada repo.

## Ejecución local (Docker Desktop)
```
cd mq       →  copy .env.example .env  →  docker compose up -d
cd kafka    →  copy .env.example .env  →  docker compose up -d
cd apps     →  copy .env.example .env  →  docker compose -f compose.aws.yml up -d --build
```
En local `MQ_HOST` y `KAFKA_HOST` son `host.docker.internal`, y las carpetas de los repos se ajustan con las variables `REPO_*` de `apps/.env`.
