# Guia da Home

## O que você vai construir

A Home é a primeira tela após o login: cumprimenta o jogador, oferece a entrada para jogar e mostra um resumo da conta. Ela deve usar a sessão autenticada que `main.dart` já restaura. A dock de navegação fica no contêiner do app, conforme [guia da dock](../../../guia_dock.md); a Home desenha apenas seu conteúdo.

## 1. Localize o ponto de partida

- `lib/main.dart` já cria `ApiClient`, restaura `AuthSession` e decide entre `LoginPage` e `HomePage`.
- `presentation/home_page.dart` já mostra `session.user.nickname`, `session.user.rankingPoints` e o catálogo. É uma tela provisória: o `CatalogoPage` ocupa o corpo inteiro.
- `AuthSession.user` é um `PlayerUser` com `id`, `nickname` e `rankingPoints`. Não há campo de foto, e-mail ou moedas permanentes.
- `ApiClient` anexa `X-Player-Token` automaticamente às chamadas feitas por repositórios.

Leia esses arquivos antes de editar. O tutorial antigo em `presentation/index.md` explica uma alternativa de composição de dependências, mas contém atalhos ainda não implementados; use os caminhos reais acima ao integrar.

## 2. Defina a responsabilidade da tela

Transforme `HomePage` em um painel com saudação, um botão **Jogar** e atalhos para **Ranking** e **Catálogo**. Deixe o botão **Sair** ligado ao `onLogout` recebido de `main.dart`. A dock pode oferecer as mesmas seções; nesse caso, os atalhos da Home são entradas rápidas para a mesma navegação, sem criar uma segunda pilha de telas.

Uma Home simples não precisa de controller. Ela recebe dados e callbacks:

```dart
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onPlay,
    required this.onRanking,
    required this.onCatalog,
  });

  final AuthSession session;
  final VoidCallback onPlay;
  final VoidCallback onRanking;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Olá, ${session.user.nickname}',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Jogar'),
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('Ranking'),
            onTap: onRanking,
          ),
          ListTile(
            leading: const Icon(Icons.style),
            title: const Text('Catálogo'),
            onTap: onCatalog,
          ),
        ],
      );
}
```

O exemplo é o **corpo** da aba: se a dock estiver em um `Scaffold` pai, não crie outro `Scaffold`/`NavigationBar` aqui. Se implementar a Home antes da dock, envolva temporariamente o corpo em um `Scaffold`.

## 3. Ligue as ações aos serviços

No contêiner autenticado descrito no [guia da dock](../../../guia_dock.md), use `onPlay` para selecionar a aba Lobby, `onRanking` para selecionar Ranking e `onCatalog` para selecionar Catálogo. O contêiner cria e entrega os casos de uso às abas. A Home não instancia `ApiClient` nem chama HTTP.

O catálogo existente já consulta `GET /cards` por `ListCardsUseCase(CardCatalogRepositoryImpl(_api))`. Ao mover `CatalogoPage` para a aba Catálogo, preserve esse caso de uso. Para a pontuação **atual** do jogador, não confie indefinidamente no valor salvo no login: chame `GetRankingUseCase(RankingRepositoryImpl(_api))` ao abrir ou atualizar o resumo e procure a entrada com `entry.id == session.user.id`. Mantenha `session.user.rankingPoints` como valor inicial enquanto a consulta termina. A API expõe `GET /users/ranking`; não há `GET /users/me` no contrato presente.

```dart
final entries = await getRanking();
final mine = entries.where((entry) => entry.id == session.user.id);
final points = mine.isEmpty
    ? session.user.rankingPoints
    : mine.first.rankingPoints;
```

Coloque esse carregamento em `initState` de uma Home com estado ou em um `HomeController`, nunca em `build`. Mostre carregamento discreto, mensagem de `AppException` e ação **Tentar novamente**. Se o ranking falhar, o jogador ainda pode navegar; o valor inicial deve ser identificado como da sessão, caso seja exibido.

## 4. Verifique o fluxo

1. Abra o app sem sessão: deve aparecer o login. Faça login e confira o apelido na Home.
2. Toque em **Jogar**, **Ranking** e **Catálogo**; cada ação deve selecionar a seção correta da dock.
3. Saia e abra o app novamente: a sessão deve estar limpa. Com sessão válida, a Home deve reaparecer sem novo login.
4. Atualize o resumo após uma mudança de pontuação: a busca pelo `id` do usuário deve substituir o valor inicial, sem supor posição fixa no ranking.

**Próximos passos:** [Lobby](../lobby/guia.md), [Ranking](../ranking/guia.md) e [dock](../../../guia_dock.md).
