#!/bin/bash
# =============================================================================
# setup.sh — Instalación de OCI CLI en Synology NAS (DSM 7.x, ARM64)
# Ejecutar como root: sudo su && bash setup.sh
# =============================================================================

set -e

OCI_DIR="/volume1/oci-cli"
SCRIPTS_DIR="/volume1/scripts"

echo ""
echo "=============================================="
echo "  OCI CLI Setup para Synology NAS"
echo "=============================================="
echo ""

# Verificar que somos root
if [ "$(id -u)" != "0" ]; then
  echo "ERROR: Este script debe ejecutarse como root (sudo su)"
  exit 1
fi

# Crear directorios
echo "[1/6] Creando directorios..."
mkdir -p "$OCI_DIR"
mkdir -p "$SCRIPTS_DIR"

# Descargar e instalar OCI CLI (ignoramos el error de backports.zoneinfo)
echo "[2/6] Descargando OCI CLI..."
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" \
  -- --install-dir "$OCI_DIR" --exec-dir "$OCI_DIR/bin" --accept-all-defaults 2>/dev/null || true

# Instalar dependencias precompiladas (evita necesidad de GCC)
echo "[3/6] Instalando dependencias..."
"$OCI_DIR/bin/pip" install oci_cli --no-deps --quiet
"$OCI_DIR/bin/pip" install --only-binary=:all: --quiet \
  certifi pyOpenSSL python-dateutil pytz urllib3 \
  circuitbreaker click jmespath prompt-toolkit \
  PyYAML six terminaltables wcwidth cryptography cffi
"$OCI_DIR/bin/pip" install "arrow==1.2.3" --no-deps --quiet
"$OCI_DIR/bin/pip" install oci --no-deps --quiet

# Añadir al PATH
echo "[4/6] Configurando PATH..."
if ! grep -q "oci-cli/bin" /root/.profile 2>/dev/null; then
  echo 'export PATH="/volume1/oci-cli/bin:$PATH"' >> /root/.profile
fi
export PATH="/volume1/oci-cli/bin:$PATH"

# Verificar instalación
echo "[5/6] Verificando instalación..."
if oci --version > /dev/null 2>&1; then
  echo "      OCI CLI $(oci --version) instalado correctamente"
else
  echo "ERROR: OCI CLI no responde. Revisa los pasos manualmente."
  exit 1
fi

# Generar clave SSH para la instancia
echo "[6/6] Generando clave SSH para la instancia..."
if [ ! -f /root/.ssh/id_rsa ]; then
  mkdir -p /root/.ssh
  ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""
  echo "      Clave SSH generada en /root/.ssh/id_rsa"
else
  echo "      Clave SSH ya existe en /root/.ssh/id_rsa"
fi

echo ""
echo "=============================================="
echo "  Instalacion completada"
echo "=============================================="
echo ""
echo "Siguientes pasos:"
echo ""
echo "  1. Configura OCI CLI:"
echo "     oci setup config"
echo ""
echo "  2. Sube la clave publica a Oracle Cloud:"
echo "     cat /root/.oci/oci_api_key_public.pem"
echo "     -> OCI Console -> My Profile -> API Keys -> Add API Key"
echo ""
echo "  3. Verifica la conexion:"
echo "     oci iam user get --user-id TU_USER_OCID"
echo ""
echo "  4. Edita crear-instancia.py con tus OCIDs y ejecuta:"
echo "     cp crear-instancia.py $SCRIPTS_DIR/"
echo "     nohup python3 $SCRIPTS_DIR/crear-instancia.py >> $SCRIPTS_DIR/crear-instancia.log 2>&1 &"
echo ""
echo "  5. Monitoriza el progreso:"
echo "     tail -f $SCRIPTS_DIR/crear-instancia.log"
echo ""
