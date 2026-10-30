# Firma estable del APK de Android

## Por qué
Android solo deja actualizar una app si la versión nueva está firmada con la misma clave que la instalada. Sin una clave fija, cada compilación de GitHub usa una clave distinta: para instalar una versión nueva hay que desinstalar la anterior, y eso **borra la colección guardada en el teléfono** (no la de Google Sheets).

## Qué hacer (una sola vez)
La clave es un secreto: la creas tú y no se comparte por chat.

1. Crear la clave. En un PC con Java instalado, en una terminal:

   ```bash
   keytool -genkeypair -keystore pokecotiza.jks -storetype PKCS12 -alias pokecotiza -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=PokeCotiza, C=CL"
   ```

   Te pedirá una contraseña. Guárdala junto con el archivo `pokecotiza.jks` en un lugar seguro (por ejemplo, tu gestor de contraseñas): si se pierden, las próximas versiones no podrán actualizar la instalada.

2. Convertir la clave a texto (Windows, PowerShell):

   ```bash
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("pokecotiza.jks")) | Set-Content pokecotiza.b64
   ```

3. En GitHub: repositorio → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Crear dos:
   - `ANDROID_KEYSTORE_BASE64`: el contenido de `pokecotiza.b64`.
   - `ANDROID_KEYSTORE_PASSWORD`: la contraseña del paso 1.

4. La próxima compilación firmará con esa clave. La primera vez habrá que desinstalar la versión firmada con la clave de desarrollo; desde ahí, las actualizaciones se instalan encima.

## Cómo funciona
- `app/android/app/build.gradle.kts` usa la clave si existen las variables `ANDROID_KEYSTORE_PATH` y `ANDROID_KEYSTORE_PASSWORD`; si no, la de desarrollo.
- `.github/workflows/app.yml` decodifica el secreto a un archivo temporal del equipo de GitHub y avisa con una advertencia si no existe.

> Por verificar al hacerlo: los nombres de menú de GitHub ("Settings → Secrets and variables → Actions") según la interfaz vigente.
