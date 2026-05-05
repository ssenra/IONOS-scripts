# Scripts de Gestión de VMs en IONOS Cloud

Scripts Bash para encender y apagar máquinas virtuales en IONOS Cloud a través de la API REST v6.

## Instalación del CLI de IONOS (`ionosctl`)

Los scripts usan `curl` directamente contra la API REST, pero `ionosctl` es útil para encontrar el ID del datacenter, los IDs de los servidores y gestionar los tokens de API.

### Linux

**Snap:**
```bash
snap install ionosctl
```

**Binario manual (amd64):**
```bash
curl -sL https://github.com/ionos-cloud/ionosctl/releases/download/v6.9.8/ionosctl-6.9.8-linux-amd64.tar.gz | tar -xzv
sudo mv ionosctl /usr/local/bin
```

Para otras arquitecturas (`arm64`, `386`) descarga el tarball correspondiente desde la [página de releases](https://github.com/ionos-cloud/ionosctl/releases/latest).

### macOS

```bash
brew tap ionos-cloud/homebrew-ionos-cloud
brew install ionosctl
```

### Windows

```powershell
scoop bucket add ionos-cloud https://github.com/ionos-cloud/scoop-bucket.git
scoop install ionos-cloud/ionosctl
```

O descarga el `.zip` para tu arquitectura desde la [página de releases](https://github.com/ionos-cloud/ionosctl/releases/latest) y añade la carpeta a tu `PATH`.

### Verificar la instalación

```bash
ionosctl version
ionosctl help
```

### Autenticarse y encontrar tus IDs

```bash
# Iniciar sesión (solicita usuario/contraseña o token)
ionosctl login

# Listar datacenters para encontrar IONOS_DATACENTER_ID
ionosctl datacenter list

# Listar servidores en un datacenter
ionosctl server list --datacenter-id <datacenter-id>
```

---

## Requisitos

- `bash`
- `curl`
- `python3` (usado por `vm.sh` para parsear JSON)

## Configuración

Copia y edita el archivo env antes de usarlo:

```bash
cp ionos-vms.env my-env.env
```

| Variable             | Descripción                                              |
|----------------------|----------------------------------------------------------|
| `IONOS_TOKEN`        | Token bearer de la API de IONOS Cloud                    |
| `IONOS_DATACENTER_ID`| ID del datacenter de destino                             |
| `VM_NAMES`           | Nombres de VMs separados por comas (scripts por lotes)   |

**Cómo obtener tus credenciales:**
- Token de API: Consola de IONOS Cloud → Menú → Claves API
- ID del datacenter: Consola de IONOS Cloud → Infraestructura → Data Center Designer → selecciona tu DC → Panel de información

## Scripts

### `vm.sh` — Controlar una VM individual por nombre

Busca la VM por su nombre en el datacenter de IONOS Cloud.

```bash
# Encender una VM
./vm.sh start asemesql01

# Apagar una VM
./vm.sh stop asemesql01

# Listar todas las VMs del datacenter (nombre, estado, ID de servidor)
./vm.sh list

# Usar un archivo env personalizado (por defecto: ionos-vms.env)
./vm.sh start asemesql01 produccion.env
```

### `vm-start.sh` — Encender todas las VMs del archivo env

Itera sobre todos los nombres de VM listados en `VM_NAMES`, resuelve el UUID de cada una
consultando la API y envía una petición de inicio.

```bash
./vm-start.sh [archivo-env]
```

### `vm-stop.sh` — Apagar todas las VMs del archivo env

Itera sobre todos los nombres de VM listados en `VM_NAMES`, resuelve el UUID de cada una
consultando la API y envía una petición de apagado.
Pasa `force` como segundo argumento para cortar la alimentación inmediatamente.

```bash
# Apagado (por defecto)
./vm-stop.sh [archivo-env]

# Corte de alimentación forzado
./vm-stop.sh [archivo-env] force
```

## Notas

- Todos los scripts usan `ionos-vms.env` en el directorio actual por defecto si no se especifica un archivo env.
- Las llamadas a la API devuelven HTTP `202 Accepted` en caso de éxito; el cambio de estado real ocurre de forma asíncrona en el lado de IONOS.
- `vm-stop.sh` usa la acción `stop` de IONOS por defecto. La opción `force` usa `poweroff`, equivalente a desenchufar el cable de alimentación.
