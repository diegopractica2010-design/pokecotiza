# Instalar PokeCotiza

## Descargar
- **Versiones publicadas:** pestaña **Releases** del repositorio. Cada versión trae `pokecotiza-vX.Y.Z-android.apk` y `pokecotiza-vX.Y.Z-windows.zip`.
- **Última compilación de prueba:** pestaña **Actions → App (Android y Windows)**, última ejecución en verde, sección "Artifacts" (se guardan 30 días).

## Android
1. Descarga el `.apk` en el teléfono (o pásalo desde el PC).
2. Ábrelo. Android pedirá permitir "instalar apps de origen desconocido" para el navegador o el administrador de archivos: acéptalo solo para esta instalación.
3. Abre PokeCotiza.

**Actualizar:** instala la versión nueva encima. Si Android dice que el paquete "entra en conflicto", la versión anterior se firmó con otra clave: hay que desinstalarla primero, y eso **borra la colección guardada en el teléfono** (no la de Google Sheets). Para evitarlo, configura la clave fija: [firma-android.md](firma-android.md).

## Windows
1. Descarga el `.zip` y descomprímelo en una carpeta propia (por ejemplo, `Documentos\PokeCotiza`).
2. Abre `pokecotiza.exe` (el zip ya trae las DLL de Visual C++ que necesita). Windows SmartScreen puede advertir que la app no está firmada: "Más información → Ejecutar de todas formas".
3. Opcional: clic derecho en `pokecotiza.exe` → "Anclar a Inicio".

**Actualizar:** reemplaza la carpeta por la nueva. La colección local se guarda aparte (en la carpeta de datos de la app), así que no se pierde.

## Primeros pasos
1. **Agregar carta:** cámara (Android), escribir nombre y número, o importar Excel (menú ⋮).
2. **Vincular TCGmatch y AFK Store** en la pantalla de confirmación (pegando el enlace), para tener precios de Chile.
3. **Google Sheets (opcional):** Ajustes ⚙ → Conectar con Google. Requiere configurar credenciales una vez: [google-cloud.md](google-cloud.md).
4. **Tarea diaria (opcional):** [tarea-diaria.md](tarea-diaria.md).

## Publicar una versión nueva (para el dueño)
Crear una etiqueta de versión en `main`:

```bash
git tag v0.1.0
```

```bash
git push origin v0.1.0
```

El workflow "Publicar versión" compila, prueba y crea el Release con los dos instaladores. También se puede crear desde GitHub: **Releases → Draft a new release → Choose a tag → v0.1.0 → Publish**; el workflow le agrega los instaladores unos minutos después.
