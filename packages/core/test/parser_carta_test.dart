import 'package:pokecotiza_core/pokecotiza_core.dart';
import 'package:test/test.dart';

void main() {
  group('leerTextoCarta', () {
    test('carta en inglés con número y PS', () {
      final d = leerTextoCarta('''
STAGE 1
Lucario-GX HP 210
Aura Strike 30+
5ban Graphics 122/131
''');
      expect(d.nombre, 'Lucario-GX');
      expect(d.ps, 210);
      expect(d.numero, '122/131');
      expect(d.numeroLocal, '122');
    });

    test('carta en español con regulación y código de set', () {
      final d = leerTextoCarta('''
BÁSICO
Charmander
PS 70
Ascuas 30
G PAF ES 007/091
''');
      expect(d.nombre, 'Charmander');
      expect(d.ps, 70);
      expect(d.regulacion, 'G');
      expect(d.codigoSet, 'PAF');
      expect(d.numero, '007/091');
      expect(d.numeroLocal, '007');
    });

    test('carta japonesa', () {
      final d = leerTextoCarta('''
たね
ピカチュウ
HP 70
G SV2a 025/165
''');
      expect(d.nombre, 'ピカチュウ');
      expect(d.ps, 70);
      expect(d.codigoSet, 'SV2a');
      expect(d.regulacion, 'G');
      expect(d.numero, '025/165');
    });

    test('tolera espacios alrededor de la barra y PS después del número', () {
      final d = leerTextoCarta('Pikachu 60 HP\nH SV4 063 / 182');
      expect(d.nombre, 'Pikachu');
      expect(d.ps, 60);
      expect(d.numero, '063/182');
      expect(d.codigoSet, 'SV4');
      expect(d.regulacion, 'H');
    });

    test('no confunde "Etapa 1" con el nombre', () {
      final d = leerTextoCarta('ETAPA 1\nLucario-GX PS 210\n5ban Graphics 122/131');
      expect(d.nombre, 'Lucario-GX');
      expect(d.totalSet, 131);
    });

    test('no confunde al ilustrador con el código de set', () {
      final d = leerTextoCarta('BASIC\nExeggcute HP 40\nYuka Morii 1/131');
      expect(d.codigoSet, isNull);
      expect(d.regulacion, isNull);
      expect(d.numero, '1/131');
    });

    test('reconoce códigos de set en minúscula si llevan dígitos', () {
      final d = leerTextoCarta('ピカチュウ\nHP 70\nG sv2a 025/165');
      expect(d.codigoSet, 'sv2a');
      expect(d.regulacion, 'G');
    });

    test('texto sin datos reconocibles no falla', () {
      final d = leerTextoCarta('   \n\n');
      expect(d.nombre, isNull);
      expect(d.numero, isNull);
      expect(d.ps, isNull);
    });
  });

  test('Condicion.desdeTexto reconoce abreviaturas y nombres', () {
    expect(Condicion.desdeTexto('NM'), Condicion.nm);
    expect(Condicion.desdeTexto('near-mint'), Condicion.nm);
    expect(Condicion.desdeTexto('Lightly Played'), Condicion.lp);
    expect(Condicion.desdeTexto('dmg'), Condicion.dmg);
    expect(Condicion.desdeTexto('nueva'), isNull);
  });
}
