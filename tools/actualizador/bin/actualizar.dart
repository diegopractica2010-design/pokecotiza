// Tarea diaria de PokeCotiza (GitHub Actions).
//
// Variables de entorno:
//   GOOGLE_SERVICE_ACCOUNT_JSON  JSON de la cuenta de servicio (secreto).
//   POKECOTIZA_ID_PLANILLA       Id o enlace de la planilla.
//
// La planilla debe estar compartida (como Editor) con el correo de la cuenta
// de servicio. Ver docs/tarea-diaria.md.
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:pokecotiza_core/pokecotiza_core.dart';

Future<void> main() async {
  final json = Platform.environment['GOOGLE_SERVICE_ACCOUNT_JSON'] ?? '';
  final idPlanilla = idPlanillaDesdeEnlace(Platform.environment['POKECOTIZA_ID_PLANILLA'] ?? '');
  if (json.trim().isEmpty || idPlanilla == null) {
    stderr.writeln('Faltan GOOGLE_SERVICE_ACCOUNT_JSON o POKECOTIZA_ID_PLANILLA. Ver docs/tarea-diaria.md.');
    exitCode = 2;
    return;
  }

  final base = http.Client();
  final credenciales = auth.ServiceAccountCredentials.fromJson(jsonDecode(json));
  auth.AccessCredentials? acceso;
  Future<String> token() async {
    final a = acceso;
    if (a == null || a.accessToken.expiry.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
      acceso = await auth.obtainAccessCredentialsViaServiceAccount(
          credenciales, const ['https://www.googleapis.com/auth/spreadsheets'], base);
    }
    return acceso!.accessToken.data;
  }

  final web = ClienteCortes(userAgent: 'PokeCotiza/0.1 (tarea diaria, uso personal)');
  try {
    final planilla = PlanillaColeccion(SheetsCliente(token, cliente: base), idPlanilla);
    final cotizador = Cotizador(
        tcgdex: TcgdexCliente(web),
        tcgmatch: TcgmatchCliente(web),
        mindicador: MindicadorCliente(web),
        tiendas: TiendaShopifyCliente(web));
    final r = await actualizarColeccion(planilla, cotizador);
    stdout.write(r.resumen());
    final resumenGitHub = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (resumenGitHub != null) {
      File(resumenGitHub).writeAsStringSync('```\n${r.resumen()}```\n', mode: FileMode.append);
    }
  } on FuenteNoDisponible catch (e) {
    stderr.writeln('No se pudo usar la planilla: $e');
    exitCode = 1;
  } finally {
    web.cerrar();
    base.close();
  }
}
