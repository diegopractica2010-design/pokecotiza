import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import '../main.dart';
import '../servicios/estado.dart';
import '../util/formato.dart';
import 'agregar.dart';
import 'ajustes.dart';
import 'detalle.dart';

class PantallaColeccion extends StatelessWidget {
  const PantallaColeccion({super.key, required this.estado, this.contexto});

  final EstadoApp estado;

  /// Null en pruebas: oculta Ajustes.
  final Contexto? contexto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final progreso = estado.progreso;
        return Scaffold(
          appBar: AppBar(
            title: const Text('PokeCotiza'),
            actions: [
              if (contexto != null)
                IconButton(
                  tooltip: 'Ajustes',
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PantallaAjustes(
                        estado: estado,
                        ajustes: contexto!.ajustes,
                        local: contexto!.local,
                        sesion: contexto!.sesion,
                        crearSheets: contexto!.crearSheets,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Actualizar precios',
                onPressed: progreso != null || estado.cartas.isEmpty ? null : estado.actualizarPrecios,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaAgregar(estado: estado))),
            icon: const Icon(Icons.add),
            label: const Text('Agregar carta'),
          ),
          body: estado.cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: estado.actualizarPrecios,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _Total(estado: estado),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text('Guardada: ${estado.almacen.descripcion}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      if (progreso != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: progreso.$2 == 0 ? null : progreso.$1 / progreso.$2),
                        Text('Actualizando precios: ${progreso.$1} de ${progreso.$2}'),
                      ],
                      if (estado.error != null) _Aviso(texto: estado.error!),
                      for (final f in estado.invalidas)
                        _Aviso(texto: 'Fila ${f.numeroFila} de la colección con error: ${f.motivo}'),
                      const SizedBox(height: 8),
                      if (estado.cartas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            'Tu colección está vacía.\nToca "Agregar carta" para cotizar la primera.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final c in estado.cartas) _FilaCarta(estado: estado, carta: c),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    final t = estado.total;
    final estilo = Theme.of(context).textTheme;
    final copias = estado.cartas.fold<int>(0, (s, c) => s + c.cantidad);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valor de la colección · $copias ${copias == 1 ? 'carta' : 'cartas'}', style: estilo.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 32, runSpacing: 8, children: [
              _Cifra(etiqueta: 'Publicado', valor: pesos(t.publicadoClp)),
              _Cifra(etiqueta: 'Ventas reales', valor: pesos(t.ventasClp)),
            ]),
            if (estado.tipoCambio != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Dólar: ${pesos(estado.tipoCambio!.usd.round())} · Euro: ${pesos(estado.tipoCambio!.eur.round())} '
                  '(${fechaCorta(estado.tipoCambio!.fecha)})',
                  style: estilo.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiqueta, style: estilo.bodySmall),
      Text(valor, style: estilo.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      color: esquema.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(texto, style: TextStyle(color: esquema.onErrorContainer)),
      ),
    );
  }
}

class _FilaCarta extends StatelessWidget {
  const _FilaCarta({required this.estado, required this.carta});

  final EstadoApp estado;
  final CartaColeccion carta;

  @override
  Widget build(BuildContext context) {
    final cot = estado.cotizaciones[carta.id];
    final detalles = [
      carta.numero,
      nombreIdioma(carta.idioma),
      if (carta.gradeo != null) carta.gradeo.toString() else carta.condicion.abreviatura,
      if (carta.acabado != Acabado.normal) nombreAcabado(carta.acabado),
      if (carta.cantidad > 1) '×${carta.cantidad}',
    ].whereType<String>().join(' · ');
    return Card(
      child: ListTile(
        title: Text(carta.nombre),
        subtitle: Text(detalles),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pesos(cot?.valor.publicadoClp), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(cot == null ? 'sin cotizar' : 'ventas ${pesos(cot.valor.ventasClp)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => PantallaDetalle(estado: estado, idCarta: carta.id))),
      ),
    );
  }
}
