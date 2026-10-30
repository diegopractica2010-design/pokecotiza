# Conectar PokeCotiza con tu Google Sheets

La app usa tus propias credenciales de Google: nadie más tiene acceso a tu planilla. Se configura una sola vez (unos 15–20 minutos).

> Los nombres de menú se revisaron el 2026-10-30 con la ayuda de Google ("Google Auth Platform → Clients"), pero la consola cambia seguido. Si algo no coincide, busca la opción equivalente.

## 1. Proyecto y APIs
1. Entra a https://console.cloud.google.com con tu cuenta y crea un proyecto (por ejemplo "PokeCotiza").
2. En "APIs y servicios → Biblioteca", activa **Google Sheets API**.

## 2. Pantalla de consentimiento (Google Auth Platform)
1. Abre **Google Auth Platform** y registra la app: nombre "PokeCotiza", tu correo como contacto.
2. Tipo de usuario: **Externo**.
3. En **Audiencia** (o "Usuarios de prueba"), agrega tu propio correo de Gmail.
4. En **Acceso a datos** (o "Permisos"), agrega `https://www.googleapis.com/auth/spreadsheets`.

### Importante: sesión cada 7 días
Mientras la app esté en "Prueba", Google vence la sesión **cada 7 días** y la app pedirá iniciar sesión otra vez. Lo dicen foros de desarrolladores de Google; no se confirmó en la documentación oficial. Opciones:
- **Aceptarlo** (lo más simple): en Ajustes vuelves a tocar "Conectar".
- **Publicar la app** ("En producción"). Google podría pedir verificación por el permiso de Sheets o mostrar un aviso de "app no verificada". **Por verificar** antes de hacerlo.

La tarea diaria (fase 6) no se ve afectada: usa una cuenta de servicio en vez de tu sesión.

## 3. Credenciales (Clients)
En **Google Auth Platform → Clients → Create client**, crea:

| Tipo | Para qué | Qué anotar |
|---|---|---|
| **Aplicación web** | La pide Android (`serverClientId`); no necesita URLs | El *ID de cliente* |
| **Android** | Teléfono. Paquete: `cl.pokecotiza.pokecotiza`. Huella SHA-1 de la clave de firma | Nada (Google la reconoce por paquete y huella) |
| **App de escritorio** | Windows | *ID de cliente* y *secreto del cliente* |

**Android necesita la clave de firma fija** ([firma-android.md](firma-android.md)): la huella SHA-1 se saca de esa clave:

```bash
keytool -list -v -keystore pokecotiza.jks -alias pokecotiza
```

Copia la línea "SHA1". Con la clave de desarrollo, la huella cambia en cada compilación y el inicio de sesión en Android fallará.

## 4. Pasar las credenciales a la compilación
En GitHub: repositorio → **Settings → Secrets and variables → Actions**.

| Nombre | Dónde | Valor |
|---|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | Variables | ID de cliente **web** |
| `GOOGLE_DESKTOP_CLIENT_ID` | Variables | ID de cliente **de escritorio** |
| `GOOGLE_DESKTOP_CLIENT_SECRET` | Secrets | Secreto del cliente de escritorio |

La próxima compilación las incluye. En la app: **Ajustes (⚙) → Conectar con Google y crear planilla**. En el otro dispositivo: **Ajustes → pegar el enlace de la planilla**.

> Según Google, en apps de escritorio el "secreto del cliente" no se considera confidencial (va dentro de la app instalada). Igual se guarda como secreto del repositorio para no dejarlo a la vista. Por verificar en la documentación de Google.
