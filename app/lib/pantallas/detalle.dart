import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicios/estado.dart';
import '../util/formato.dart';
import 'confirmar.dart';
import 'historial_futuro.dart';

class PantallaDetalle extends StatelessWidget {
  const PantallaDetalle({super.key, required this.estado, required this.idCarta});

  final EstadoApp estado;
  final String idCarta;

  Future<void> _eliminar(BuildContext context, CartaColeccion carta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar ${carta.nombre}?'),
        content: const Text('Se quita de tu colección.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await estado.eliminar(carta.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) {
        final carta = estado.cartas.where((c) => c.id == idCarta).firstOrNull;
        if (carta == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('La carta ya no existe.')));
        final cot = estado.cotizaciones[idCarta];
        final estilo = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(carta.nombre),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PantallaConfirmar(estado: estado, base: carta, editando: true))),
              ),
              IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminar(context, carta)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                [
                  carta.numero,
                  nombreIdioma(carta.idioma),
                  nombreAcabado(carta.acabado),
                  carta.gradeo?.toString() ?? carta.condicion.abreviatura,
                  'cantidad ${carta.cantidad}',
                ].whereType<String>().join(' · '),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 32, runSpacing: 8, children: [
                _Cifra('Publicado (mediana)', pesos(cot?.valor.publicadoClp)),
                _Cifra('Ventas reales', pesos(cot?.valor.ventasClp)),
              ]),
              if (carta.cantidad > 1 && cot?.valor.publicadoClp != null)
                Text('Total por ${carta.cantidad} copias: ${pesos(cot!.valor.publicadoClp! * carta.cantidad)}',
                    style: estilo.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(cot == null ? 'Aún sin cotizar.' : 'Cotizada el ${fechaCorta(cot.fecha)}',
                      style: estilo.bodySmall),
                ),
                TextButton.icon(
                  onPressed: () => estado.cotizarUna(carta),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar precio'),
                ),
              ]),
              if (cot != null)
                for (final f in cot.fallas.entries)
                  Text('${f.key} no respondió: ${f.value}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (carta.tcgmatchId == null && carta.gradeo == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'Sin vínculo con TCGmatch: falta el precio del mercado chileno. Usa "Editar" para pegar el enlace.'),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Evolución', style: estilo.titleSmall),
              const SizedBox(height: 8),
              HistorialFuturo(version: estado.versionHistorial, cargar: () => estado.almacen.historialCarta(carta)),
              const SizedBox(height: 16),
              if (cot != null && cot.cotizaciones.isNotEmpty) ...[
                Text('Precios por fuente', style: estilo.titleSmall),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Fuente')),
                      DataColumn(label: Text('Tipo')),
                      DataColumn(label: Text('Original'), numeric: true),
                      DataColumn(label: Text('En pesos'), numeric: true),
                    ],
                    rows: [
                      for (final q in cot.cotizaciones)
                        DataRow(cells: [
                          DataCell(Text(q.fuente), onTap: q.url == null ? null : () => launchUrl(q.url!)),
                          DataCell(Text(q.tipo == TipoPrecio.ventas ? 'ventas' : 'publicado')),
                          DataCell(Text(monedaOriginal(q.valor, q.moneda))),
                          DataCell(Text(estado.tipoCambio == null
                              ? '—'
                              : pesos(estado.tipoCambio!.aClp(q.valor, q.moneda).round()))),
                        ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.etiqueta, this.valor);

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
