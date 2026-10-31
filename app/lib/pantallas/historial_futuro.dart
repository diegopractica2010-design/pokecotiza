import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'grafico.dart';

/// Gráfico de historial que solo vuelve a leer los datos cuando cambia
/// [version] (no en cada redibujo de la pantalla). Leer la planilla de
/// Precios completa en cada redibujo sería lento y gastaría cuota de Google.
class HistorialFuturo extends StatefulWidget {
  const HistorialFuturo({super.key, required this.version, required this.cargar, this.alto = 160});

  final int version;
  final Future<List<PuntoValor>> Function() cargar;
  final double alto;

  @override
  State<HistorialFuturo> createState() => _HistorialFuturoState();
}

class _HistorialFuturoState extends State<HistorialFuturo> {
  late Future<List<PuntoValor>> _futuro = widget.cargar();

  @override
  void didUpdateWidget(HistorialFuturo viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.version != widget.version) _futuro = widget.cargar();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PuntoValor>>(
        future: _futuro,
        builder: (_, s) => s.hasData
            ? GraficoValor(puntos: s.data!, alto: widget.alto)
            : SizedBox(
                height: 48, child: s.hasError ? const Center(child: Text('No se pudo leer el historial.')) : null),
      );
}
