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
  final TipoCambio cambio;
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
      ..writeln('Dólar: ${cambio.usd} · Euro: ${cambio.eur} (${cambio.fecha.toUtc().toIso8601String()})');
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
  final cambio = await cotizador.tipoCambio(ultimoConocido: await planilla.leerTipoCambio());
  await planilla.guardarTipoCambio(cambio);
  final r = ResultadoActualizacion(fecha: fecha, cambio: cambio);

  final leida = await planilla.leerColeccion();
  r.filasInvalidas.addAll(leida.invalidas);
  r.cartas = leida.cartas.length;
  final valores = <(CartaColeccion, ValorCarta)>[];
  for (final carta in leida.cartas) {
    final c = await cotizador.cotizar(carta, cambio, ahora: fecha);
    valores.add((carta, c.valor));
    if (c.fallas.isNotEmpty) r.fallas[carta.nombre] = c.fallas;
    if (c.cotizaciones.isNotEmpty) {
      r.cotizadas++;
      try {
        await planilla.registrarPrecios(carta.id, c.cotizaciones, cambio, fecha: fecha);
      } on FuenteNoDisponible catch (e) {
        r.fallas[carta.nombre] = {...?r.fallas[carta.nombre], 'Google Sheets': e.mensaje};
      }
    } else if (c.valor.manual) {
      r.cotizadas++;
    }
  }
  r.total = valorColeccion(valores);
  await planilla.registrarResumen(r.total, r.cartas, fecha: fecha);
  return r;
}
