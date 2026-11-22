#!/bin/sh
# Crea los tópicos del caso (sección 9) si no existen y termina (Exited 0). Se puede correr varias veces.
set -eu

BS=kafka-1:29092,kafka-2:29092,kafka-3:29092

# crear <tópico> <retención en ms> <política>: 3 particiones, 3 réplicas, min.insync.replicas 2
crear() {
  kafka-topics --bootstrap-server "$BS" --create --if-not-exists \
    --topic "$1" --partitions 3 --replication-factor 3 \
    --config retention.ms="$2" --config min.insync.replicas=2
  kafka-configs --bootstrap-server "$BS" --alter --entity-type topics --entity-name "$1" \
    --add-config "cleanup.policy=$3"
}

# shipments.events: eventos del envío (lo publica shipments; lo leen report y audit). delete, 7 días
crear shipments.events 604800000 delete
# audit.timeline: quién, qué, cuándo y desde dónde (lo publica shipments; lo lee audit). compact,delete, 30 días
crear audit.timeline 2592000000 "[compact,delete]"
# DLT, uno por consumidor: mensajes que fallaron tras los reintentos. delete, 14 días
crear report.DLT 1209600000 delete
crear audit.DLT 1209600000 delete

kafka-topics --bootstrap-server "$BS" --describe --topic shipments.events
kafka-topics --bootstrap-server "$BS" --describe --topic audit.timeline
echo "RUTAEXPRESS KAFKA: tópicos listos"
