# Fase 7: leer la carta con la cámara (Android)

Hecha el 2026-10-31.

## Cómo funciona
1. En "Agregar carta", elegir el idioma y tocar **Leer la carta con la cámara**.
2. Se saca una foto con la cámara del teléfono (`image_picker` 1.2.4).
3. Google ML Kit lee el texto **en el teléfono** (`google_mlkit_text_recognition` 0.17.1): modelo japonés para cartas japonesas y latino para el resto. La foto no se envía a ningún servidor y se borra después de leerla.
4. El lector del núcleo (`leerTextoCarta`) saca nombre, PS, número, set y regulación, completa los campos y busca en TCGdex.
5. Siempre se confirma la carta en la lista de candidatas.

- **Windows:** el botón no aparece (ML Kit solo existe para Android e iOS); se escribe a mano o se importa Excel.
- **Android:** el modelo japonés se agrega en `android/app/build.gradle.kts` (`com.google.mlkit:text-recognition-japanese:16.0.1`, según la documentación del paquete). Requisitos de ML Kit (minSdk 21, compileSdk 35) cubiertos por los de Flutter (24 y 36).

## Pruebas
- 3 pruebas de la pantalla con un lector falso: lee, completa y busca; nombre ilegible (avisa y no busca); sin cámara no hay botón.

## Sin verificar
- **El OCR con fotos reales:** no hay un teléfono en este entorno. Lo esperable con cartas reales: texto chico del número, reflejos en holo, fuentes estilizadas. Si falla seguido, ajustar `leerTextoCarta` con ejemplos reales del dueño.
- Que la cámara funcione en el teléfono del dueño (permisos según la versión de Android).
