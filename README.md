# 🚀 OCI Free Tier Instance Creator — Synology NAS

Script de reintento automático para crear una instancia **VM.Standard.A1.Flex** (ARM/Ampere) en Oracle Cloud Free Tier desde un NAS Synology. Útil cuando la región está sin capacidad y necesitas seguir intentándolo hasta que se libere un hueco.

---

## ¿Por qué existe esto?

Las instancias gratuitas de Oracle Cloud (4 OCPUs + 24GB RAM con arquitectura ARM) son muy populares. Oracle responde con `Out of host capacity` cuando no hay hueco disponible. La solución es reintentar automáticamente hasta que se libere capacidad — idealmente desde un dispositivo encendido 24/7 como un NAS Synology.

---

## Requisitos

- NAS Synology con DSM 7.x
- Acceso SSH habilitado
- Cuenta de Oracle Cloud con Free Tier activo
- Python 3.8+ (incluido en DSM)

---

## Instalación

### 1. Habilitar SSH en Synology

DSM → **Control Panel → Terminal & SNMP → Enable SSH**

Conéctate desde tu PC:
```bash
ssh tu_usuario@IP-DE-TU-NAS
sudo su
```

### 2. Instalar OCI CLI

```bash
mkdir -p /volume1/oci-cli

bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" \
  -- --install-dir /volume1/oci-cli --exec-dir /volume1/oci-cli/bin --accept-all-defaults
```

> **Nota para Synology:** El instalador fallará al compilar `backports.zoneinfo` por falta de GCC. Esto es normal. Continúa con los pasos siguientes.

Instala las dependencias precompiladas:
```bash
/volume1/oci-cli/bin/pip install oci_cli --no-deps
/volume1/oci-cli/bin/pip install --only-binary=:all: \
  certifi pyOpenSSL python-dateutil pytz urllib3 \
  circuitbreaker click jmespath prompt-toolkit \
  PyYAML six terminaltables wcwidth cryptography cffi
/volume1/oci-cli/bin/pip install "arrow==1.2.3" --no-deps
/volume1/oci-cli/bin/pip install oci --no-deps
```

Añade el CLI al PATH:
```bash
echo 'export PATH="/volume1/oci-cli/bin:$PATH"' >> /root/.profile
export PATH="/volume1/oci-cli/bin:$PATH"
oci --version
```

### 3. Configurar OCI CLI

```bash
oci setup config
```

Necesitarás:
- **User OCID** → OCI Console → perfil (arriba derecha) → My Profile → copia el OCID
- **Tenancy OCID** → OCI Console → perfil → Tenancy → copia el OCID
- **Region** → p.ej. `eu-madrid-1` o `eu-frankfurt-1`
- Genera una nueva clave API (opción Y)

Sube la clave pública a Oracle Cloud:
```bash
cat /root/.oci/oci_api_key_public.pem
```
Ve a OCI Console → **My Profile → API Keys → Add API Key → Paste Public Key** y pega el contenido.

> **Importante:** Si regeneras las claves, actualiza el fingerprint en el config:
> ```bash
> openssl rsa -pubout -outform DER -in /root/.oci/oci_api_key.pem 2>/dev/null | openssl md5 -c
> sed -i "s|fingerprint=.*|fingerprint=TU_FINGERPRINT|" /root/.oci/config
> ```

Verifica la conexión:
```bash
oci iam user get --user-id TU_USER_OCID
```

### 4. Generar clave SSH para la instancia

```bash
ssh-keygen -t rsa -b 2048 -f /root/.ssh/id_rsa -N ""
```

### 5. Obtener los parámetros necesarios

```bash
# Availability Domains disponibles
oci iam availability-domain list --compartment-id TU_TENANCY_OCID

# Subnet ID
oci network subnet list --compartment-id TU_TENANCY_OCID

# Imagen Ubuntu ARM más reciente
oci compute image list \
  --compartment-id TU_TENANCY_OCID \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.A1.Flex" \
  --query 'data[0].id'
```

---

## Configuración del script

Edita `crear-instancia.py` y rellena las variables:

```python
COMPARTMENT_ID      = "ocid1.tenancy.oc1..XXXX"
AVAILABILITY_DOMAIN = "XXXX:EU-MADRID-1-AD-1"
SUBNET_ID           = "ocid1.subnet.oc1.eu-madrid-1.XXXX"
IMAGE_ID            = "ocid1.image.oc1.eu-madrid-1.XXXX"
SSH_KEY_PATH        = "/root/.ssh/id_rsa.pub"
INSTANCE_NAME       = "mi-instancia-free"
OCPUS               = 4      # Máximo 4 en Free Tier
MEMORY_GB           = 24     # Máximo 24 en Free Tier
ESPERA_SEGUNDOS     = 120    # Tiempo entre intentos
```

---

## Uso

Copia el script al NAS:
```bash
mkdir -p /volume1/scripts
cp crear-instancia.py /volume1/scripts/
```

Ejecútalo en segundo plano:
```bash
nohup python3 /volume1/scripts/crear-instancia.py >> /volume1/scripts/crear-instancia.log 2>&1 &
echo "Script iniciado con PID: $!"
```

Monitoriza el progreso:
```bash
tail -f /volume1/scripts/crear-instancia.log
```

Detén el script:
```bash
pkill -f crear-instancia.py
```

---

## Comportamiento del script

| Respuesta de Oracle | Acción |
|---|---|
| Éxito (código 0) | Para el script y muestra los detalles de la instancia |
| `Out of host capacity` | Espera `ESPERA_SEGUNDOS` y reintenta |
| `TooManyRequests` | Espera 300 segundos y reintenta |
| Cualquier otro error | Para el script para revisión manual |

---

## Consejos

- Madrid (`eu-madrid-1`) tiene solo 1 Availability Domain y suele estar llena. Frankfurt (`eu-frankfurt-1`) tiene más capacidad.
- La capacidad suele liberarse de **madrugada** (2-6am).
- Si en 48h no hay suerte, prueba reducir a 2 OCPUs y 12GB — hay más probabilidades de que haya hueco.
- El script está pensado para correr días o semanas hasta conseguirlo.

---

## Estructura del repositorio

```
.
├── README.md
├── crear-instancia.py   # Script principal de reintento
└── setup.sh             # Instalación automática de OCI CLI en Synology
```
