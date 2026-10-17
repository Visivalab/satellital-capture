# Despliegue de satellital-capture

Alta de la aplicación en el servidor compartido ya preparado (Storylab), según la sección 5 de la guía de despliegue multiproyecto. No hay que repetir la instalación de la infraestructura.

| Concepto | Valor |
|---|---|
| Repositorio / rama | `Visivalab/satellital-capture` / `master` |
| Aplicación autorizada | `satellital-capture` |
| Imagen fija | `ghcr.io/visivalab/satellital-capture` (`linux/amd64`) |
| Variable de imagen | `SATELLITAL_CAPTURE_IMAGE` |
| Compose protegido | `/etc/company-deploy/compose/satellital-capture.yaml` |
| Configuración | `/opt/satellital-capture/.env` (vacío; no se reenvía ninguna variable) |
| Proyecto / servicio | `satellital-capture` / `satellital-capture` |
| Puerto | contenedor `8080` → host `127.0.0.1:<primer libre desde 3002>` (lo elige `setup-server.sh`) |
| Salud | `GET /health` |
| Datos persistentes | Ninguno: las capturas se generan en un directorio temporal |

## Atajo

```bash
# Servidor (pasos 1–4 y 6 de abajo). Elige el primer puerto libre desde 3002 (backend)
# y desde 8081 (Caddy); en ejecuciones posteriores conserva el ya instalado.
# Borrar antes la copia anterior: si el destino existe, scp -r copia dentro de él
ssh USUARIO@SERVIDOR rm -rf ~/satellital-capture-deploy
scp -r deployment USUARIO@SERVIDOR:~/satellital-capture-deploy
ssh -t USUARIO@SERVIDOR sudo bash ~/satellital-capture-deploy/setup-server.sh

# GitHub (secretos, variables y entorno)
./deployment/setup-github.sh ~/.ssh/visivalab-ci-deploy
```

## En el servidor (cuenta de administración)

1. Elegir un puerto libre (`sudo ss -ltnp` no debe mostrarlo ni debe aparecer en otro Compose) y ponerlo en `compose.yaml` y en Caddy.
2. Instalar el Compose protegido (copiado antes al servidor):

   ```bash
   sudo install -o root -g root -m 644 ~/compose.yaml /etc/company-deploy/compose/satellital-capture.yaml
   ```

3. Crear el `.env` vacío:

   ```bash
   sudo install -d -o root -g root -m 755 /opt/satellital-capture
   sudo install -o root -g root -m 644 /dev/null /opt/satellital-capture/.env
   ```

4. Añadir la entrada de `project-entry.json` dentro de `projects` en `/etc/company-deploy/projects.json`, **sin borrar `storylab`**, y validar:

   ```bash
   sudo python3 -c 'import json; json.load(open("/etc/company-deploy/projects.json")); print("JSON correcto")'
   ```

5. Dar acceso de lectura al paquete GHCR `satellital-capture` a la cuenta con la que root hizo `docker login ghcr.io` (tras el primer push, en la configuración del paquete en GitHub).
6. Añadir a Caddy un sitio privado que apunte a ese puerto, sin tocar los existentes. Validar antes de recargar. Las capturas grandes pueden tardar hasta 5 minutos: no pongas un timeout de proxy menor.

## En GitHub (Settings → Secrets and variables → Actions del repositorio)

- Secretos: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`, `DEPLOY_SSH_PRIVATE_KEY`, `DEPLOY_KNOWN_HOSTS` (los mismos valores que Storylab).
- Variables: `DEPLOY_HOST`, `DEPLOY_PORT` (`22`). `DEPLOY_ENABLED=false` pausa el despliegue automático; sin configurar, cada push a `master` despliega.
- Crear el entorno `production` si no existe (lo usa `deploy.yml`).

## Uso

- Cada push a `master` publica la imagen y la despliega con su digest exacto.
- Para volver a desplegar un digest anterior: **Actions → Deploy published image → Run workflow**, aplicación `satellital-capture`.
