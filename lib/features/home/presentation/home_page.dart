import 'package:flutter/material.dart';

import '../../auth/domain/entities/auth_session.dart';
import '../../catalog/domain/usecases/list_cards_usecase.dart';
import '../../catalog/presentation/pages/catalogo_page.dart';

/// Tela inicial provisória após o login.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.listCards,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final ListCardsUseCase listCards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${session.user.nickname}'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('Pontos de ranking'),
            trailing: Text('${session.user.rankingPoints}'),
          ),
          Expanded(child: CatalogoPage(listCards: listCards)),
        ],
      ),
    );
  }
}
