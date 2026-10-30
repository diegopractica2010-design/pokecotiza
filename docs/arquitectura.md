# Arquitectura (diseño en papel)

## Vista general

```
 ┌──────────────── Android (Flutter) ───────────────┐   ┌──── Windows (Flutter) ────┐
 │ Cámara → OCR en el dispositivo → parser de carta │   │ Ingreso manual            │
 │ Ingreso manual                                   │   │ Importar .xlsx / Sheets   │
 └───────────────┬──────────────────────────────────┘   └────────────┬──────────────┘
                 │       ambas usan el mismo paquete Dart            │
                 ▼                                                   ▼
        ┌─────────────────────── pokecotiza_core (Dart puro) ───────────────────────┐
        │ Modelos · Identificación de carta · Adaptadores de mercado · Conversión CLP│
        │ Repositorio de colección (Google Sheets) · Caché local                     │
        └──────┬───────────────────────────┬───────────────────────────┬────────────┘
               │                           │                           │
               ▼                           ▼                           ▼
     APIs de catálogo/precios      Sitios de mercados          Google Sheets (nube)
     (TCGplayer/Cardmarket)        (scraping con caché)        Colección + Historial
                                                                       ▲
                                                                       │ lee/escribe
                              ┌────────────────────────────────────────┴──┐
                              │ GitHub Actions (cron diario, gratis)       │
                              │ CLI Dart que usa pokecotiza_core           │
                              └────────────────────────────────────────────┘
```

**Idea central:** no hay servidor propio. La lógica vive en un paquete Dart compartido (`pokecotiza_core`) que usan la app y una herramienta de línea de comandos. GitHub Actions corre esa herramienta una vez al día. Google Sheets hace de base de datos compartida entre teléfono, PC y la tarea diaria.

## Estructura del repositorio (monorepo)
```
pokecotiza/
├─ app/                    App Flutter (Android + Windows)
├─ packages/core/          pokecotiza_core: lógica sin interfaz gráfica
├─ tools/actualizador/     CLI Dart para la tarea diaria
├─ .github/workflows/      CI y actualización diaria
└─ docs/
```

## Componentes

### 1. Identificación de cartas
| Entrada | Cómo |
|---|---|
| Foto (Android) | OCR en el dispositivo (candidato: Google ML Kit Text Recognition) → texto crudo |
| Manual | Formulario con autocompletado desde el catálogo |
| Planilla (Windows) | Lectura de .xlsx o de una hoja de Sheets con columnas definidas |

**Parser de carta:** a partir del texto extrae:
- nombre
- PS/HP
- código de set
- letra de regulación
- número (`125/197`)

**Resolución:** con esos datos busca en un catálogo de cartas y devuelve candidatas ordenadas por coincidencia; el usuario confirma. El número y el código de set son las claves fuertes, y el nombre y los PS desempatan.

> Por verificar: soporte de OCR japonés en ML Kit y en Windows; qué catálogo cubre cartas en español y japonés (candidatos: Pokémon TCG API, TCGdex).

### 2. Adaptadores de mercado
Interfaz común. Cada mercado se implementa por separado y se puede desactivar sin tocar el resto:
```
MercadoAdapter
  nombre, region, moneda, soportaIdiomas, soportaGradeadas
  cotizar(CartaIdentificada) -> List<Cotizacion>
```
Orden de preferencia por fuente: **API oficial o pública → API de terceros → scraping de HTML**.
Cada consulta pasa por:
- caché, con tiempo de vida según la fuente
- límite de frecuencia por dominio
- registro de errores

### 3. Conversión de moneda
USD/EUR/JPY → CLP con un tipo de cambio diario, guardando la fecha del dato. Fuente por verificar (candidato: mindicador.cl).

### 4. Persistencia: Google Sheets
Planilla única con pestañas:
| Pestaña | Una fila por | Columnas principales |
|---|---|---|
| `Coleccion` | carta física | id, nombre, set, número, regulación, idioma, condición, gradeadora, nota, cantidad, foto, fecha_alta |
| `Precios` | cotización (historial, solo se agregan filas) | id_carta, fecha, mercado, precio, moneda, precio_clp, tipo (venta/oferta), url |
| `Resumen` | día | fecha, valor_total_clp (fórmulas) |
| `Config` | parámetro | mercados activos, tipo de cambio, etc. |

- **App:** inicia sesión con la cuenta de Google del usuario (OAuth) y lee y escribe la planilla.
- **Tarea diaria:** usa una *cuenta de servicio* de Google con acceso solo a esa planilla. La credencial se guarda como *secret* de GitHub.
- **Caché local:** SQLite en el dispositivo para funcionar sin conexión y sincronizar después.

### 5. Actualización diaria (GitHub Actions)
1. Cron una vez al día.
2. Lee `Coleccion`.
3. Cotiza cada carta con los mismos adaptadores.
4. Agrega filas a `Precios` y actualiza `Resumen`.
5. Si una fuente falla, lo registra y sigue con las demás.

> Por verificar: límites del plan gratuito de Actions según si el repo es público o privado, y si los sitios bloquean las IPs de GitHub.

### 6. Interfaz (pantallas)
1. **Colección:** lista con valor por carta y total; filtros por set, idioma y gradeo.
2. **Agregar carta:** pestañas Cámara (solo Android) / Manual / Importar (Windows).
3. **Confirmar carta:** candidatas con imagen; condición, idioma y gradeo.
4. **Detalle de carta:** precios por mercado, en moneda original y CLP, y gráfico de historial.
5. **Ajustes:** cuenta de Google, planilla, mercados activos.

## Riesgos principales
| Riesgo | Mitigación |
|---|---|
| Un sitio cambia su HTML o bloquea el scraping | Adaptadores aislados, preferir APIs, avisar en la app qué fuente falló |
| Términos de uso que prohíben scraping | Revisar cada sitio antes de implementarlo; descartarlo si lo prohíbe |
| OCR impreciso (reflejos, cartas japonesas) | Siempre se confirma la carta; las claves fuertes son set y número |
| Precios de gradeadas y japonesas sin fuente gratuita confirmada | Fase separada al final; evaluar fuentes antes de comprometerlas |
| Límites de Google Sheets | Escribir por lotes; el volumen de una colección personal debería caber (por verificar) |
