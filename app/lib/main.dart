import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pokecotiza_core/pokecotiza_core.dart';

import 'pantallas/coleccion.dart';
import 'servicios/almacen.dart';
import 'servicios/estado.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final carpeta = await getApplicationSupportDirectory();
  final http = ClienteCortes();
  final tcgdex = TcgdexCliente(http);
  final tcgmatch = TcgmatchCliente(http);
  final estado = EstadoApp(
    almacen: AlmacenLocal(File('${carpeta.path}${Platform.pathSeparator}coleccion.json')),
    cotizador: Cotizador(tcgdex: tcgdex, tcgmatch: tcgmatch, mindicador: MindicadorCliente(http)),
    tcgdex: tcgdex,
    tcgmatch: tcgmatch,
  );
  runApp(PokeCotizaApp(estado: estado));
  await estado.cargar();
}

class PokeCotizaApp extends StatelessWidget {
  const PokeCotizaApp({super.key, required this.estado});

  final EstadoApp estado;

  @override
  Widget build(BuildContext context) {
    // Amarillo del marco de las cartas como color semilla.
    const semilla = Color(0xFFF2C230);
    return MaterialApp(
      title: 'PokeCotiza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: semilla, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: semilla, brightness: Brightness.dark, useMaterial3: true),
      home: PantallaColeccion(estado: estado),
    );
  }
}
