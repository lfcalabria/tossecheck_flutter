import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tossecheck_flutter/screens/cadastro_pet_screen.dart';

void main() {
  Widget makeTestableWidget() {
    return const MaterialApp(
      home: CadastroPetScreen(),
    );
  }

  testWidgets('deve mostrar erros quando o formulário estiver vazio', (tester) async {
    await tester.pumpWidget(makeTestableWidget());

    await tester.tap(find.text('Salvar Pet'));
    await tester.pumpAndSettle();

    expect(find.text('Obrigatório'), findsWidgets);
  });

  testWidgets('deve mostrar snackbar quando Tipo e Sexo não forem selecionados', (tester) async {
    await tester.pumpWidget(makeTestableWidget());

    await tester.enterText(find.byType(TextFormField).at(0), 'Rex');
    await tester.enterText(find.byType(TextFormField).at(1), 'Poodle');
    await tester.enterText(find.byType(TextFormField).at(2), '3');
    await tester.enterText(find.byType(TextFormField).at(3), '10');
    await tester.enterText(find.byType(TextFormField).at(4), '40');

    await tester.tap(find.text('Salvar Pet'));
    await tester.pumpAndSettle();

    expect(find.text('Selecione Tipo e Sexo.'), findsOneWidget);
  });
}