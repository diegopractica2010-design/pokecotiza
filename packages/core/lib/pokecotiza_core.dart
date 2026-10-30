/// Núcleo de PokeCotiza: identificación de cartas, fuentes de precios y
/// valorización. No depende de Flutter, así que lo usan tanto la app como la
/// tarea diaria.
library;

export 'src/actualizacion.dart';
export 'src/cotizador.dart';
export 'src/errores.dart';
export 'src/fuentes/mindicador.dart';
export 'src/fuentes/tcgdex.dart';
export 'src/fuentes/tcgmatch.dart';
export 'src/http/cliente_cortes.dart';
export 'src/identificacion/parser_carta.dart';
export 'src/modelos.dart';
export 'src/planilla/esquema.dart';
export 'src/planilla/importar.dart';
export 'src/planilla/planilla_coleccion.dart';
export 'src/planilla/sheets_cliente.dart';
export 'src/valorizacion.dart';
