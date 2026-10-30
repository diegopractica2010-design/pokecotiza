import 'package:flutter/material.dart';

void main() => runApp(const PokeCotizaApp());

class PokeCotizaApp extends StatelessWidget {
  const PokeCotizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokeCotiza',
      theme: ThemeData(colorSchemeSeed: Colors.amber, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('PokeCotiza: busca una carta para cotizar')),
      ),
    );
  }
}
