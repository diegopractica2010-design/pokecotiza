import 'package:flutter/material.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicios/ajustes.dart';
import '../servicios/almacen.dart';
import '../servicios/estado.dart';
import '../servicios/sesion_google.dart';

/// Elegir dónde se guarda la colección: en el dispositivo o en Google Sheets.
class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({
    super.key,
    required this.estado,
    required this.ajustes,
    required this.local,
    required this.sesion,
    required this.crearSheets,
  });

  final EstadoApp estado;
  final Ajustes ajustes;
  final AlmacenLocal local;

  /// Null si esta compilación no trae credenciales de Google.
  final SesionGoogle? sesion;
  final SheetsCliente Function(SesionGoogle sesion) crearSheets;

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _enlace = TextEditingController();
  bool _trabajando = false;
  String? _mensaje;
  String? _error;

  @override
  void dispose() {
    _enlace.dispose();
    super.dispose();
  }

  Future<void> _conectar({required bool crearNueva}) async {
    final sesion = widget.sesion!;
    String? idExistente;
    if (!crearNueva) {
      idExistente = idPlanillaDesdeEnlace(_enlace.text);
      if (idExistente == null) {
        setState(() => _error = 'Pega el enlace de la planilla (https://docs.google.com/spreadsheets/d/...).');
        return;
      }
    }
    setState(() {
      _trabajando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      if (!await sesion.conectada()) await sesion.iniciar();
      final sheets = widget.crearSheets(sesion);
      final planilla = crearNueva ? await PlanillaColeccion.crear(sheets) : PlanillaColeccion(sheets, idExistente!);
      if (!crearNueva) await planilla.prepararEstructura();
      final subidas = await migrarALaPlanilla(widget.local, planilla);
      widget.ajustes.idPlanilla = planilla.idPlanilla;
      await widget.ajustes.guardar();
      await widget.estado.cambiarAlmacen(AlmacenPlanilla(planilla, widget.local));
      setState(() => _mensaje = 'Conectado. ${subidas == 0 ? '' : 'Se subieron $subidas cartas del dispositivo. '}'
          'Usa este mismo enlace en tu otro dispositivo.');
    } on Object catch (e) {
      setState(() => _error = 'No se pudo conectar: $e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _desconectar() async {
    widget.ajustes.idPlanilla = null;
    await widget.ajustes.guardar();
    await widget.sesion?.cerrar();
    await widget.estado.cambiarAlmacen(widget.local);
    setState(
        () => _mensaje = 'Desconectado. La app vuelve a usar la copia del dispositivo (puede estar desactualizada).');
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.ajustes.idPlanilla;
    final estilo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dónde se guarda tu colección', style: estilo.titleMedium),
          const SizedBox(height: 8),
          Text(id == null ? 'En este dispositivo.' : 'En Google Sheets.'),
          if (id != null) ...[
            const SizedBox(height: 8),
            SelectableText(enlacePlanilla(id).toString(), style: estilo.bodySmall),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                onPressed: () => launchUrl(enlacePlanilla(id), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir planilla'),
              ),
              TextButton.icon(
                onPressed: _trabajando ? null : _desconectar,
                icon: const Icon(Icons.link_off),
                label: const Text('Desconectar'),
              ),
            ]),
          ],
          const Divider(height: 32),
          if (widget.sesion == null)
            const Text('Esta versión de la app no trae credenciales de Google, así que solo puede guardar en el '
                'dispositivo. Para activarlo, sigue la guía docs/google-cloud.md del repositorio.')
          else if (id == null) ...[
            Text('Guardar en Google Sheets', style: estilo.titleMedium),
            const SizedBox(height: 4),
            const Text('Así el teléfono y el PC ven la misma colección. Las cartas que ya tengas en este '
                'dispositivo se suben a la planilla.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _trabajando ? null : () => _conectar(crearNueva: true),
              icon: const Icon(Icons.add_chart),
              label: const Text('Conectar con Google y crear planilla'),
            ),
            const SizedBox(height: 16),
            const Text('¿Ya la creaste en tu otro dispositivo? Pega aquí su enlace:'),
            const SizedBox(height: 8),
            TextField(
              controller: _enlace,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enlace de la planilla',
                  hintText: 'https://docs.google.com/spreadsheets/d/...'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _trabajando ? null : () => _conectar(crearNueva: false),
              icon: const Icon(Icons.link),
              label: const Text('Conectar con esa planilla'),
            ),
          ],
          if (_trabajando) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_mensaje != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_mensaje!)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
