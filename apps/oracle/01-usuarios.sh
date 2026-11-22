#!/bin/bash
# Crea un usuario (esquema) por servicio en ORCLPDB1: "Oracle en contenedor, un esquema por servicio" (contratos)
# SHIPMENTS_USER ya lo crea la imagen con APP_USER. Este script suma los de catalog, report y audit.
# Lo ejecuta la imagen gvenzl/oracle-free UNA sola vez, cuando crea la base (volumen vacío).
# createAppUser <usuario> <contraseña> [<PDB>] viene incluido en la imagen.
set -euo pipefail

createAppUser CATALOG_USER "${CATALOG_DB_PASSWORD:?Falta CATALOG_DB_PASSWORD}" ORCLPDB1
createAppUser REPORT_USER  "${REPORT_DB_PASSWORD:?Falta REPORT_DB_PASSWORD}"  ORCLPDB1
createAppUser AUDIT_USER   "${AUDIT_DB_PASSWORD:?Falta AUDIT_DB_PASSWORD}"   ORCLPDB1

echo "RUTAEXPRESS ORACLE: usuarios CATALOG_USER, REPORT_USER y AUDIT_USER listos"
