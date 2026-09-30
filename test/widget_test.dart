import 'package:flutter_test/flutter_test.dart';
import 'package:trunocrazy/main.dart';

void main() {
  testWidgets('sem sessão salva, abre a tela de login', (tester) async {
    await tester.pumpWidget(const TrunoCrazyApp());
    await tester.pumpAndSettle();

    expect(find.text('Truno Crazzy'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
