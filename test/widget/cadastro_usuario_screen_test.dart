import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// troque app pelo nome real do seu pacote
import 'package:tossecheck_flutter/screens/cadastro_usuario_screen.dart';

void main() {
  Widget makeTestableWidget() {
    return const MaterialApp(
      home: CadastroUsuarioScreen(),
    );
  }

  testWidgets('deve mostrar erro quando o nome estiver vazio', (tester) async {
    await tester.pumpWidget(makeTestableWidget());

    await tester.enterText(find.byType(TextFormField).at(1), '12345678901');
    await tester.enterText(find.byType(TextFormField).at(2), '81999998888');

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu nome'), findsOneWidget);
  });

  testWidgets('deve mostrar erro quando o CPF tiver menos de 11 dígitos', (tester) async {
    await tester.pumpWidget(makeTestableWidget());

    await tester.enterText(find.byType(TextFormField).at(0), 'João da Silva');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.enterText(find.byType(TextFormField).at(2), '81999998888');

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('O CPF deve ter exatamente 11 dígitos'), findsOneWidget);
  });

  testWidgets('deve mostrar erro quando o telefone tiver menos de 11 dígitos', (tester) async {
    await tester.pumpWidget(makeTestableWidget());

    await tester.enterText(find.byType(TextFormField).at(0), 'João da Silva');
    await tester.enterText(find.byType(TextFormField).at(1), '12345678901');
    await tester.enterText(find.byType(TextFormField).at(2), '81');

    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Telefone deve ter 11 dígitos (DDD+9)'), findsOneWidget);
  });
}