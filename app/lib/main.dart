import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'pantallas/coleccion.dart';
import 'servicios/ajustes.dart';
import 'servicios/almacen.dart';
import 'servicios/estado.dart';
import 'servicios/sesion_google.dart';

/// Lo que necesitan las pantallas además del estado: ajustes y Google.
class Contexto {
  Contexto({required this.ajustes, required this.local, required this.sesion});

  final Ajustes ajustes;
  final AlmacenLocal local;
  final SesionGoogle? sesion;

  SheetsCliente crearSheets(SesionGoogle s) => SheetsCliente(s.token);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final carpeta = await getApplicationSupportDirectory();
  String ruta(String nombre) => '${carpeta.path}${Platform.pathSeparator}$nombre';
  final http = ClienteCortes();
  final tcgdex = TcgdexCliente(http);
  final tcgmatch = TcgmatchCliente(http);
  final local = AlmacenLocal(File(ruta('coleccion.json')));
  final ajustes = Ajustes(File(ruta('ajustes.json')));
  await ajustes.cargar();
  final contexto = Contexto(ajustes: ajustes, local: local, sesion: crearSesionGoogle());

  final estado = EstadoApp(
    almacen: local,
    cotizador: Cotizador(tcgdex: tcgdex, tcgmatch: tcgmatch, mindicador: MindicadorCliente(http)),
    tcgdex: tcgdex,
    tcgmatch: tcgmatch,
  );
  // Si la colección está en Google Sheets, se usa la planilla. Si la sesión no
  // está disponible, se muestra la copia del dispositivo con un aviso.
  final id = ajustes.idPlanilla;
  final sesion = contexto.sesion;
  if (id != null && sesion != null && await sesion.conectada()) {
    estado.almacen = AlmacenPlanilla(PlanillaColeccion(contexto.crearSheets(sesion), id), local);
  }
  runApp(PokeCotizaApp(estado: estado, contexto: contexto));
  await estado.cargar();
  if (id != null && estado.almacen is! AlmacenPlanilla) {
    estado.error =
        'No se pudo abrir tu planilla de Google: inicia sesión de nuevo en Ajustes. Mientras, ves la copia del dispositivo.';
  }
}

class PokeCotizaApp extends StatelessWidget {
  const PokeCotizaApp({super.key, required this.estado, this.contexto});

  final EstadoApp estado;
  final Contexto? contexto;

  @override
  Widget build(BuildContext context) {
    // Amarillo del marco de las cartas como color semilla.
    const semilla = Color(0xFFF2C230);
    return MaterialApp(
      title: 'PokeCotiza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: semilla, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: semilla, brightness: Brightness.dark, useMaterial3: true),
      home: PantallaColeccion(estado: estado, contexto: contexto),
    );
  }
}
