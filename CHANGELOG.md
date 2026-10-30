# Changelog

## [Sin publicar]
### Añadido
- Fase 3: módulo de planilla (Google Sheets) en el núcleo: colección, historial de precios, resumen y tipo de cambio, con 12 pruebas (incluye correcciones de la revisión de Codex).
- Página de pruebas del núcleo (lector compilado a JavaScript y generador de datos).
- Fase 2: paquete `pokecotiza_core` (modelos, lector de texto de cartas, clientes TCGdex/TCGmatch/mindicador, valorización) con 24 pruebas y CI.
- Fase 1 cerrada: gradeadas manuales, eBay descartado, Mercado Libre pospuesto, TCGdex aprobado.
- Fase 1: informe de investigación de fuentes y propuesta para integrar TCGmatch.
- Fuentes chilenas (TCGmatch y otras tiendas) con revisión inicial de robots.txt.
- Licencia: todos los derechos reservados.
- Condición por carta (RF-13) y fotos en Google Drive (RF-14).
- Requisitos de valorización (promedio publicado y de ventas reales) y de condición de carta.
- Documentación inicial: requisitos, arquitectura, fuentes de precios, plan de trabajo y decisiones.

### Corregido
- Lector: "Etapa N" ya no se toma como nombre; el ilustrador ya no se toma como código de set.
- TCGplayer: ya no se usa la variante de otro acabado (revisión de Codex).
- Cliente HTTP: peticiones simultáneas al mismo sitio respetan la pausa (revisión de Codex).
- Lector: acepta códigos de set en minúscula con dígitos (revisión de Codex).
- TCGdex: máximo 6 consultas de expansiones por búsqueda y reintento de totales fallidos (revisión de Codex).
- TCGdex: la búsqueda tolera guiones en el nombre, filtra números exactos y ordena por total de la expansión.
