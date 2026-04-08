import subprocess, time, logging
from datetime import datetime

# =============================================================================
# CONFIGURACIÓN — rellena estos valores antes de ejecutar
# =============================================================================
COMPARTMENT_ID      = "ocid1.tenancy.oc1..XXXX"         # Tenancy o Compartment OCID
AVAILABILITY_DOMAIN = "XXXX:EU-MADRID-1-AD-1"            # Nombre del AD (ver README)
SUBNET_ID           = "ocid1.subnet.oc1.eu-madrid-1.XXXX"
IMAGE_ID            = "ocid1.image.oc1.eu-madrid-1.XXXX" # Imagen Ubuntu ARM
SSH_KEY_PATH        = "/root/.ssh/id_rsa.pub"             # Clave SSH para la instancia
INSTANCE_NAME       = "mi-instancia-free"
OCPUS               = 4      # Máximo 4 en Free Tier
MEMORY_GB           = 24     # Máximo 24 en Free Tier
ESPERA_SEGUNDOS     = 120    # Segundos entre intentos normales
ESPERA_RATE_LIMIT   = 300    # Segundos de espera si Oracle dice TooManyRequests
LOG_FILE            = "/volume1/scripts/crear-instancia.log"
OCI_BIN             = "/volume1/oci-cli/bin/oci"
# =============================================================================

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

def log(msg):
    logging.info(msg)
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def intentar_crear():
    cmd = [
        OCI_BIN, "compute", "instance", "launch",
        "--compartment-id",           COMPARTMENT_ID,
        "--availability-domain",      AVAILABILITY_DOMAIN,
        "--subnet-id",                SUBNET_ID,
        "--image-id",                 IMAGE_ID,
        "--shape",                    "VM.Standard.A1.Flex",
        "--shape-config",             f'{{"ocpus":{OCPUS},"memoryInGBs":{MEMORY_GB}}}',
        "--display-name",             INSTANCE_NAME,
        "--ssh-authorized-keys-file", SSH_KEY_PATH,
        "--assign-public-ip",         "true"
    ]
    return subprocess.run(cmd, capture_output=True, text=True)

intento = 0
log("Iniciando script de reintento para OCI...")
log(f"Shape: VM.Standard.A1.Flex | {OCPUS} OCPUs | {MEMORY_GB}GB RAM")
log(f"Region/AD: {AVAILABILITY_DOMAIN}")

while True:
    intento += 1
    log(f"Intento #{intento}...")
    r = intentar_crear()
    output = r.stdout + r.stderr

    if r.returncode == 0:
        log("EXITO! Instancia creada correctamente.")
        log(r.stdout)
        break
    elif any(x in output.lower() for x in ["out of capacity", "out of host capacity", "internalerror"]):
        log(f"Sin capacidad. Reintentando en {ESPERA_SEGUNDOS}s...")
        time.sleep(ESPERA_SEGUNDOS)
    elif "TooManyRequests" in output:
        log(f"Rate limit alcanzado. Esperando {ESPERA_RATE_LIMIT}s...")
        time.sleep(ESPERA_RATE_LIMIT)
    else:
        log("Error inesperado — deteniendo script para revision manual:")
        log(output)
        break
