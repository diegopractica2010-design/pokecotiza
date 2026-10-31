import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import '../util/formato.dart';

/// Gráfico de líneas del valor en el tiempo: publicado y ventas reales.
/// Dibujado a mano para no sumar dependencias.
class GraficoValor extends StatelessWidget {
  const GraficoValor({super.key, required this.puntos, this.alto = 160});

  final List<PuntoValor> puntos;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.bodySmall!;
    final conDatos = puntos.where((p) => p.publicadoClp != null || p.ventasClp != null).toList();
    if (conDatos.isEmpty) {
      return SizedBox(
        height: 48,
        child: Center(child: Text('Aún no hay historial: aparece al actualizar precios.', style: estilo)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: alto,
        width: double.infinity,
        child: CustomPaint(
          painter: _Pintor(
            puntos: conDatos,
            colorPublicado: esquema.primary,
            colorVentas: esquema.tertiary,
            colorEjes: esquema.outlineVariant,
            estilo: estilo.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Wrap(spacing: 16, children: [
        _Leyenda(color: esquema.primary, texto: 'Publicado'),
        _Leyenda(color: esquema.tertiary, texto: 'Ventas reales'),
      ]),
    ]);
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});
  final Color color;
  final String texto;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _Pintor extends CustomPainter {
  _Pintor({
    required this.puntos,
    required this.colorPublicado,
    required this.colorVentas,
    required this.colorEjes,
    required this.estilo,
  });

  final List<PuntoValor> puntos;
  final Color colorPublicado;
  final Color colorVentas;
  final Color colorEjes;
  final TextStyle estilo;

  TextPainter _texto(String t) =>
      TextPainter(text: TextSpan(text: t, style: estilo), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final valores = [
      for (final p in puntos) ...[p.publicadoClp, p.ventasClp]
    ].whereType<int>().toList();
    var minimo = valores.reduce(min).toDouble();
    var maximo = valores.reduce(max).toDouble();
    if (minimo == maximo) {
      // Una línea plana se dibuja al medio.
      minimo -= max(1, minimo.abs() * 0.1);
      maximo += max(1, maximo.abs() * 0.1);
    }
    final etiquetaMax = _texto(pesos(maximo.round()));
    final etiquetaMin = _texto(pesos(minimo.round()));
    final izquierda = max(etiquetaMax.width, etiquetaMin.width) + 8;
    const abajo = 18.0;
    final area = Rect.fromLTRB(izquierda, 6, size.width - 4, size.height - abajo);

    final t0 = puntos.first.fecha.millisecondsSinceEpoch.toDouble();
    final t1 = puntos.last.fecha.millisecondsSinceEpoch.toDouble();
    double x(DateTime f) =>
        t1 == t0 ? area.center.dx : area.left + (f.millisecondsSinceEpoch - t0) / (t1 - t0) * area.width;
    double y(int v) => area.bottom - (v - minimo) / (maximo - minimo) * area.height;

    final ejes = Paint()
      ..color = colorEjes
      ..strokeWidth = 1;
    canvas.drawLine(area.bottomLeft, area.bottomRight, ejes);
    canvas.drawLine(
        Offset(area.left, area.top), Offset(area.right, area.top), ejes..color = colorEjes.withValues(alpha: 0.4));
    etiquetaMax.paint(canvas, Offset(0, area.top - etiquetaMax.height / 2));
    etiquetaMin.paint(canvas, Offset(0, area.bottom - etiquetaMin.height / 2));
    String dia(DateTime f) {
      final l = f.toLocal();
      return '${l.day.toString().padLeft(2, '0')}-${l.month.toString().padLeft(2, '0')}';
    }

    final desde = _texto(dia(puntos.first.fecha));
    desde.paint(canvas, Offset(area.left, area.bottom + 3));
    if (puntos.length > 1) {
      final hasta = _texto(dia(puntos.last.fecha));
      hasta.paint(canvas, Offset(area.right - hasta.width, area.bottom + 3));
    }

    void serie(int? Function(PuntoValor) valor, Color color) {
      final linea = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final camino = Path();
      var empezado = false;
      Offset? ultimo;
      for (final p in puntos) {
        final v = valor(p);
        if (v == null) continue;
        final o = Offset(x(p.fecha), y(v));
        empezado ? camino.lineTo(o.dx, o.dy) : camino.moveTo(o.dx, o.dy);
        empezado = true;
        ultimo = o;
      }
      canvas.drawPath(camino, linea);
      if (ultimo != null) canvas.drawCircle(ultimo, 3.5, Paint()..color = color);
    }

    serie((p) => p.ventasClp, colorVentas);
    serie((p) => p.publicadoClp, colorPublicado);
  }

  @override
  bool shouldRepaint(_Pintor viejo) => viejo.puntos != puntos || viejo.colorPublicado != colorPublicado;
}
