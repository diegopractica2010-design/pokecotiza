# Plan de trabajo

Cada fase termina con algo usable y se revisa antes de pasar a la siguiente.

| Fase | Objetivo | Entregables | Depende de |
|---|---|---|---|
| **0. Levantamiento y diseño** ✅ | Definir qué se construye | README, requisitos, arquitectura, mercados, plan, plantillas de issues | — |
| **1. Investigación de fuentes** ✅ | Validar cada fuente antes de programar | Tabla de mercados actualizada con API/ToS/límites, más una prueba mínima de cada una | 0 |
| **2. Núcleo** ✅ | Lógica sin interfaz | `packages/core`: modelos, parser de carta, clientes TCGdex/TCGmatch/mindicador, valorización, pruebas, CI. Ver [estado de la fase 2](fase-2-nucleo.md) | 1 |
| **3. Google Sheets** ✅ | Persistencia compartida | Estructura de la planilla y lectura/escritura de Colección, Precios, Resumen y Config en el núcleo. Ver [fase 3](fase-3-planilla.md). El inicio de sesión con Google pasa a la fase 4 | 2 |
| **4. App: ingreso manual y cotización** 🚧 ([detalle](fase-4-app.md)) | Primera versión usable | Inicio de sesión con Google y prueba contra Sheets real; pantallas Colección / Agregar (manual) / Confirmar / Detalle, en Android y Windows | 2, 3 |
| **5. Mercados internacionales** ✅ (TCGplayer y Cardmarket vía TCGdex, fase 2) | Precios de referencia | Adaptadores TCGplayer y Cardmarket (vía API) | 1, 2 |
| **6. Tarea diaria** 🚧 ([detalle](tarea-diaria.md)) | Historial automático | `tools/actualizador` + workflow de GitHub Actions + pestaña Resumen | 3, 5 |
| **7. Cámara (Android)** | Escanear cartas | OCR + parser + resolución de candidatas | 2, 4 |
| **8. Importar/Exportar** ✅ ([detalle](fase-8-excel.md); en Android y Windows) | Carga masiva | Importar .xlsx/Sheets con validación; exportar .xlsx | 3, 4 |
| **9. Mercados chilenos** | Precios en CLP | Mercado Libre + tiendas que indique el dueño | 1 |
| **10. Japonés y gradeadas** | Cobertura completa | Adaptadores JP y de gradeadas según la investigación de la fase 1 | 1, 7 |
| **11. Historial y gráficos** | Ver evolución | Gráficos por carta y colección | 6 |
| **12. Publicación** | Instalables | APK firmado (Android) e instalador para Windows, con guía de instalación | todas |

## Cómo se trabajará
- Una rama y un pull request por funcionalidad, enlazados a un issue.
- Cada adaptador de mercado incluye pruebas con respuestas guardadas, para detectar cuando un sitio cambia.
- CI en GitHub Actions: análisis estático y pruebas en cada pull request.
- Las decisiones nuevas se anotan en `docs/decisiones.md`.
