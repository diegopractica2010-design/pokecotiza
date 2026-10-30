import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Permiso pedido a Google: leer y escribir planillas de Google Sheets.
/// Ver docs/decisiones.md (decisión 32).
const permisosGoogle = ['https://www.googleapis.com/auth/spreadsheets'];

/// Credenciales OAuth incluidas al compilar (--dart-define). Vienen de la
/// configuración del repositorio; ver docs/google-cloud.md.
const _idClienteWeb = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const _idClienteEscritorio = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const _secretoClienteEscritorio = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

/// Sesión con la cuenta de Google del usuario, para obtener un token de
/// acceso a Google Sheets.
abstract class SesionGoogle {
  /// True si ya hay una sesión que se puede usar sin pedir nada al usuario.
  Future<bool> conectada();

  /// Pide al usuario que inicie sesión y autorice el permiso.
  Future<void> iniciar();

  /// Token de acceso vigente (lo renueva si hace falta).
  Future<String> token();

  Future<void> cerrar();
}

/// La sesión adecuada a la plataforma, o null si esta compilación no trae
/// credenciales de Google.
SesionGoogle? crearSesionGoogle() {
  if (Platform.isAndroid && _idClienteWeb.isNotEmpty) return SesionGoogleAndroid(_idClienteWeb);
  if (Platform.isWindows && _idClienteEscritorio.isNotEmpty) {
    return SesionGoogleEscritorio(auth.ClientId(_idClienteEscritorio, _secretoClienteEscritorio));
  }
  return null;
}

class SinSesionGoogle implements Exception {
  const SinSesionGoogle(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Android: google_sign_in 7 (Credential Manager).
class SesionGoogleAndroid implements SesionGoogle {
  SesionGoogleAndroid(this.idClienteWeb);

  final String idClienteWeb;
  GoogleSignInAccount? _cuenta;
  Future<void>? _inicializado;

  Future<void> _init() => _inicializado ??= GoogleSignIn.instance.initialize(serverClientId: idClienteWeb);

  Future<GoogleSignInAccount?> _silenciosa() async {
    await _init();
    return _cuenta ??= await (GoogleSignIn.instance.attemptLightweightAuthentication() ?? Future.value(null));
  }

  @override
  Future<bool> conectada() async => (await _silenciosa()) != null;

  @override
  Future<void> iniciar() async {
    await _init();
    _cuenta = await GoogleSignIn.instance.authenticate(scopeHint: permisosGoogle);
    await _cuenta!.authorizationClient.authorizeScopes(permisosGoogle);
  }

  @override
  Future<String> token() async {
    final cuenta = await _silenciosa();
    if (cuenta == null) throw const SinSesionGoogle('Inicia sesión con Google en Ajustes.');
    final autorizacion = await cuenta.authorizationClient.authorizationForScopes(permisosGoogle);
    if (autorizacion == null) throw const SinSesionGoogle('Vuelve a autorizar el acceso a Google Sheets en Ajustes.');
    return autorizacion.accessToken;
  }

  @override
  Future<void> cerrar() async {
    await _init();
    await GoogleSignIn.instance.signOut();
    _cuenta = null;
  }
}

/// Windows: inicio de sesión en el navegador (googleapis_auth). La sesión se
/// guarda cifrada en el equipo con flutter_secure_storage.
class SesionGoogleEscritorio implements SesionGoogle {
  SesionGoogleEscritorio(this.cliente, {FlutterSecureStorage? almacen, http.Client? http_})
      : _almacen = almacen ?? const FlutterSecureStorage(),
        _http = http_ ?? http.Client();

  static const _clave = 'pokecotiza_google_credenciales';
  final auth.ClientId cliente;
  final FlutterSecureStorage _almacen;
  final http.Client _http;
  auth.AccessCredentials? _credenciales;

  Future<auth.AccessCredentials?> _leer() async {
    if (_credenciales != null) return _credenciales;
    final texto = await _almacen.read(key: _clave);
    if (texto == null) return null;
    try {
      return _credenciales = auth.AccessCredentials.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } on Object {
      await _almacen.delete(key: _clave);
      return null;
    }
  }

  Future<void> _guardar(auth.AccessCredentials c) async {
    _credenciales = c;
    await _almacen.write(key: _clave, value: jsonEncode(c.toJson()));
  }

  @override
  Future<bool> conectada() async => (await _leer())?.refreshToken != null;

  @override
  Future<void> iniciar() async {
    final c = await auth.obtainAccessCredentialsViaUserConsent(cliente, permisosGoogle, _http, (url) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    });
    await _guardar(c);
  }

  @override
  Future<String> token() async {
    var c = await _leer();
    if (c == null) throw const SinSesionGoogle('Inicia sesión con Google en Ajustes.');
    // Se renueva un minuto antes de que expire.
    if (c.accessToken.expiry.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
      if (c.refreshToken == null) throw const SinSesionGoogle('Vuelve a iniciar sesión con Google en Ajustes.');
      c = await auth.refreshCredentials(cliente, c, _http);
      await _guardar(c);
    }
    return c.accessToken.data;
  }

  @override
  Future<void> cerrar() async {
    _credenciales = null;
    await _almacen.delete(key: _clave);
  }
}
