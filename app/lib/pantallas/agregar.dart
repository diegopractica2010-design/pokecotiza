import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import '../servicios/estado.dart';
import '../util/formato.dart';
import 'confirmar.dart';

/// Paso 1: datos de la carta (a mano o pegando su texto) y búsqueda en TCGdex.
class PantallaAgregar extends StatefulWidget {
  const PantallaAgregar({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<PantallaAgregar> createState() => _PantallaAgregarState();
}

class _PantallaAgregarState extends State<PantallaAgregar> {
  final _texto = TextEditingController();
  final _nombre = TextEditingController();
  final _numero = TextEditingController();
  Idioma _idioma = Idioma.espanol;
  List<ResultadoTcgdex>? _candidatas;
  bool _buscando = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    _nombre.dispose();
    _numero.dispose();
    super.dispose();
  }

  void _leerTexto() {
    final d = leerTextoCarta(_texto.text);
    setState(() {
      if (d.nombre != null) _nombre.text = d.nombre!;
      if (d.numero != null) _numero.text = d.numero!;
    });
  }

  Future<void> _buscar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre de la carta.');
      return;
    }
    final numero = _numero.text.trim();
    final partes = numero.split('/');
    setState(() {
      _buscando = true;
      _error = null;
      _candidatas = null;
    });
    try {
      final r = await widget.estado.tcgdex.buscar(
        idioma: _idioma,
        nombre: nombre,
        numeroLocal: numero.isEmpty ? null : partes.first.trim(),
        totalSet: partes.length > 1 ? int.tryParse(partes[1].trim()) : null,
      );
      setState(() => _candidatas = r);
    } on Object catch (e) {
      setState(() => _error = 'No se pudo buscar en TCGdex: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _elegir(ResultadoTcgdex? r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConfirmar(
          estado: widget.estado,
          base: CartaColeccion(
            id: EstadoApp.nuevoId(),
            nombre: r?.nombre ?? _nombre.text.trim(),
            idioma: _idioma,
            numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
            tcgdexId: r?.id,
            fechaAlta: DateTime.now(),
          ),
          imagen: r?.imagen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidatas = _candidatas;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar carta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            title: const Text('Pegar el texto de la carta (opcional)'),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _texto,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Lucario-GX PS 210\n5ban Graphics 122/131',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: _leerTexto,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Leer datos del texto')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numero,
            decoration: const InputDecoration(
                labelText: 'Número (ej. 122/131)',
                border: OutlineInputBorder(),
                helperText: 'El número de abajo de la carta'),
            onSubmitted: (_) => _buscar(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Idioma>(
            initialValue: _idioma,
            decoration: const InputDecoration(labelText: 'Idioma de la carta', border: OutlineInputBorder()),
            items: [for (final i in Idioma.values) DropdownMenuItem(value: i, child: Text(nombreIdioma(i)))],
            onChanged: (i) => setState(() => _idioma = i ?? _idioma),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _buscando ? null : _buscar,
            icon: _buscando
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: const Text('Buscar en TCGdex'),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (candidatas != null) ...[
            const SizedBox(height: 16),
            Text(
              candidatas.isEmpty
                  ? 'No se encontró en TCGdex. Revisa el nombre y el número, o agrégala sin catálogo.'
                  : 'Elige la carta correcta (${candidatas.length} ${candidatas.length == 1 ? 'resultado' : 'resultados'}):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final r in candidatas)
              Card(
                child: ListTile(
                  leading: _Miniatura(url: r.imagen),
                  title: Text(r.nombre),
                  subtitle: Text('${r.id} · número ${r.numeroLocal}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _elegir(r),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _nombre.text.trim().isEmpty && candidatas == null ? null : () => _elegir(null),
              child: const Text('Agregar sin catálogo (por ejemplo, una gradeada)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final vacio = Container(width: 40, height: 56, color: Theme.of(context).colorScheme.surfaceContainerHighest);
    if (url == null) return vacio;
    return Image.network('$url/low.webp',
        width: 40, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => vacio);
  }
}
