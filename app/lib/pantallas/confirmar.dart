import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicios/estado.dart';
import '../util/formato.dart';

/// Paso 2: confirmar la carta, elegir acabado, condición y cantidad, y
/// vincularla con TCGmatch. También sirve para editar una carta existente.
class PantallaConfirmar extends StatefulWidget {
  const PantallaConfirmar({super.key, required this.estado, required this.base, this.imagen, this.editando = false});

  final EstadoApp estado;
  final CartaColeccion base;
  final String? imagen;
  final bool editando;

  @override
  State<PantallaConfirmar> createState() => _PantallaConfirmarState();
}

class _PantallaConfirmarState extends State<PantallaConfirmar> {
  late final _nombre = TextEditingController(text: widget.base.nombre);
  late final _cantidad = TextEditingController(text: '${widget.base.cantidad}');
  late final _enlace = TextEditingController(
      text: widget.base.tcgmatchId == null ? '' : 'https://tcgmatch.cl/producto/catalogo/${widget.base.tcgmatchId}');
  late final _empresa = TextEditingController(text: widget.base.gradeo?.empresa ?? 'PSA');
  late final _nota = TextEditingController(text: widget.base.gradeo?.nota ?? '');
  late final _valorManual = TextEditingController(text: widget.base.valorManualClp?.toString() ?? '');
  late Acabado _acabado = widget.base.acabado;
  late Condicion _condicion = widget.base.condicion;
  late bool _gradeada = widget.base.gradeo != null;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _cantidad, _enlace, _empresa, _nota, _valorManual]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _abrirTcgmatch() async {
    final ok = await launchUrl(Uri.parse('https://tcgmatch.cl/cartas/pokemon'), mode: LaunchMode.externalApplication);
    if (!ok && mounted) setState(() => _error = 'No se pudo abrir el navegador.');
  }

  Future<void> _guardar() async {
    final cantidad = int.tryParse(_cantidad.text.trim());
    if (_nombre.text.trim().isEmpty) {
      return setState(() => _error = 'Falta el nombre.');
    }
    if (cantidad == null || cantidad < 1) {
      return setState(() => _error = 'La cantidad debe ser un número entero mayor que 0.');
    }
    final valorManual =
        _valorManual.text.trim().isEmpty ? null : int.tryParse(_valorManual.text.replaceAll('.', '').trim());
    if (_gradeada && (valorManual == null || valorManual < 0)) {
      return setState(() => _error = 'Para una carta gradeada ingresa su valor en pesos: un número entero, 0 o mayor.');
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      int? tcgmatchId;
      if (_enlace.text.trim().isNotEmpty) {
        try {
          tcgmatchId = await widget.estado.tcgmatch.resolverEnlace(_enlace.text);
        } on ArgumentError {
          setState(() => _error = 'El enlace no es de una carta de TCGmatch. Debe verse así: '
              'https://tcgmatch.cl/producto/catalogo/12345 o https://tcgmatch.cl/producto/...');
          return;
        }
      }
      final b = widget.base;
      final carta = CartaColeccion(
        id: b.id,
        nombre: _nombre.text.trim(),
        idioma: b.idioma,
        codigoSet: b.codigoSet,
        numero: b.numero,
        regulacion: b.regulacion,
        condicion: _condicion,
        acabado: _acabado,
        gradeo: _gradeada ? Gradeo(empresa: _empresa.text.trim(), nota: _nota.text.trim()) : null,
        cantidad: cantidad,
        tcgdexId: b.tcgdexId,
        tcgmatchId: tcgmatchId,
        valorManualClp: _gradeada ? valorManual : null,
        fotoUrl: b.fotoUrl,
        fechaAlta: b.fechaAlta ?? DateTime.now(),
      );
      await widget.estado.guardarYCotizar(carta);
      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${carta.nombre} guardada y cotizada.')));
    } on Object catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.base;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editando ? 'Editar carta' : 'Confirmar carta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.imagen != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Image.network('${widget.imagen}/low.webp',
                    width: 110, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                Text([b.numero, nombreIdioma(b.idioma), b.tcgdexId ?? 'sin catálogo'].whereType<String>().join(' · ')),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          SegmentedButton<Acabado>(
            segments: [for (final a in Acabado.values) ButtonSegment(value: a, label: Text(nombreAcabado(a)))],
            selected: {_acabado},
            onSelectionChanged: (s) => setState(() => _acabado = s.first),
          ),
          const SizedBox(height: 4),
          Text('Holo incluye las Full Art, ex, GX y V. Reverse holo: brillo fuera de la ilustración.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<Condicion>(
                initialValue: _condicion,
                decoration: const InputDecoration(labelText: 'Condición', border: OutlineInputBorder()),
                items: [
                  for (final c in Condicion.values)
                    DropdownMenuItem(value: c, child: Text('${c.abreviatura} · ${c.nombre}')),
                ],
                onChanged: _gradeada ? null : (c) => setState(() => _condicion = c ?? _condicion),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Carta gradeada'),
            subtitle: const Text('No hay una fuente gratuita de precios de gradeadas: el valor lo ingresas tú.'),
            value: _gradeada,
            onChanged: (v) => setState(() => _gradeada = v),
          ),
          if (_gradeada)
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: 120,
                  child: TextField(controller: _empresa, decoration: const InputDecoration(labelText: 'Empresa'))),
              SizedBox(
                  width: 80, child: TextField(controller: _nota, decoration: const InputDecoration(labelText: 'Nota'))),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _valorManual,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor en pesos', prefixText: '\$ '),
                ),
              ),
            ]),
          const Divider(height: 32),
          Text('Precio en Chile (TCGmatch)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text('Abre TCGmatch, busca esta carta y pega aquí el enlace de su página '
              '(o de cualquier publicación de esa carta). Se hace una sola vez.'),
          const SizedBox(height: 8),
          TextField(
            controller: _enlace,
            decoration: const InputDecoration(
                labelText: 'Enlace de TCGmatch (opcional)',
                border: OutlineInputBorder(),
                hintText: 'https://tcgmatch.cl/producto/...'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: _abrirTcgmatch, icon: const Icon(Icons.open_in_new), label: const Text('Abrir TCGmatch')),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_guardando ? 'Guardando y cotizando…' : 'Guardar y cotizar'),
          ),
        ],
      ),
    );
  }
}
