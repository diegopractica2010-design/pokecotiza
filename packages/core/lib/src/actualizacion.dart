import 'cotizador.dart';
import 'errores.dart';
import 'fuentes/mindicador.dart';
import 'modelos.dart';
import 'planilla/esquema.dart';
import 'planilla/planilla_coleccion.dart';
import 'valorizacion.dart';

/// Resultado de una actualización de toda la colección.
class ResultadoActualizacion {
  ResultadoActualizacion({required this.fecha, required this.cambio});

  final DateTime fecha;

  /// Null si no hubo tipo de cambio (mindicador.cl caído y ninguno guardado):
  /// entonces solo se usan precios en pesos.
  final TipoCambio? cambio;

  /// Cartas cuyas fuentes fallaron y se valorizaron con su último precio.
  final List<String> conPrecioAnterior = [];
  int cartas = 0;
  int cotizadas = 0;

  /// Carta (nombre) → fuentes que fallaron.
  final Map<String, Map<String, String>> fallas = {};
  final List<FilaInvalida> filasInvalidas = [];
  ({int publicadoClp, int ventasClp}) total = (publicadoClp: 0, ventasClp: 0);

  String resumen() {
    final b = StringBuffer()
      ..writeln('Actualización del ${fecha.toUtc().toIso8601String()}')
      ..writeln('Cartas: $cartas · cotizadas con al menos un precio: $cotizadas')
      ..writeln('Valor publicado: ${total.publicadoClp} CLP · ventas reales: ${total.ventasClp} CLP')
      ..writeln(cambio == null
          ? 'Sin tipo de cambio (mindicador.cl no respondió y no había uno guardado): solo se usaron precios en pesos.'
          : 'Dólar: ${cambio!.usd} · Euro: ${cambio!.eur} (${cambio!.fecha.toUtc().toIso8601String()})');
    if (conPrecioAnterior.isNotEmpty) {
      b.writeln('Con su último precio conocido (fuentes caídas hoy): ${conPrecioAnterior.join(', ')}');
    }
    for (final f in filasInvalidas) {
      b.writeln('Fila con error: $f');
    }
    for (final e in fallas.entries) {
      b.writeln('${e.key}: ${e.value.entries.map((x) => '${x.key} no respondió (${x.value})').join('; ')}');
    }
    return b.toString();
  }
}

/// Cotiza toda la colección de la planilla y registra los precios y el
/// resumen del día. Una carta o fuente que falla no detiene a las demás.
/// Lo usa la tarea diaria de GitHub Actions.
Future<ResultadoActualizacion> actualizarColeccion(PlanillaColeccion planilla, Cotizador cotizador,
    {DateTime? ahora}) async {
  final fecha = ahora ?? DateTime.now();
  TipoCambio? cambio;
  try {
    cambio = await cotizador.tipoCambio(ultimoConocido: await planilla.leerTipoCambio());
    await planilla.guardarTipoCambio(cambio);
  } on FuenteNoDisponible {
    cambio = null;
  } on FormatoInesperado {
    cambio = null;
  }
  // Sin tipo de cambio solo sirven los precios en pesos (TCGmatch y gradeadas).
  final cambioUsado = cambio ?? TipoCambio(usd: 0, eur: 0, fecha: fecha);
  List<Cotizacion> utiles(List<Cotizacion> cs) => cambio == null
      ? [
          for (final c in cs)
            if (c.moneda == Moneda.clp) c
        ]
      : cs;

  final r = ResultadoActualizacion(fecha: fecha, cambio: cambio);
  final leida = await planilla.leerColeccion();
  r.filasInvalidas.addAll(leida.invalidas);
  r.cartas = leida.cartas.length;
  Map<String, List<Cotizacion>>? anteriores;
  final valores = <(CartaColeccion, ValorCarta)>[];
  for (final carta in leida.cartas) {
    final c = await cotizador.cotizar(carta, cambioUsado, ahora: fecha);
    final cotizaciones = utiles(c.cotizaciones);
    var valor = c.valor.manual ? c.valor : valorizar(carta, cotizaciones, cambioUsado);
    if (c.fallas.isNotEmpty) r.fallas[carta.nombre] = c.fallas;
    if (cotizaciones.isNotEmpty) {
      r.cotizadas++;
      try {
        await planilla.registrarPrecios(carta.id, cotizaciones, cambioUsado, fecha: fecha);
      } on FuenteNoDisponible catch (e) {
        r.fallas[carta.nombre] = {...?r.fallas[carta.nombre], 'Google Sheets': e.mensaje};
      }
    } else if (c.valor.manual) {
      r.cotizadas++;
    } else if (c.fallas.isNotEmpty) {
      // Todas sus fuentes fallaron: se usa su último precio para no registrar una baja falsa.
      anteriores ??= await planilla.ultimasCotizaciones();
      final previas = utiles(anteriores[carta.id] ?? const []);
      if (previas.isNotEmpty) {
        valor = valorizar(carta, previas, cambioUsado);
        r.conPrecioAnterior.add(carta.nombre);
      }
    }
    valores.add((carta, valor));
  }
  r.total = valorColeccion(valores);
  await planilla.registrarResumen(r.total, r.cartas, fecha: fecha);
  return r;
}
