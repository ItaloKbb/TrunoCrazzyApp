# Tutorial: criando a Home e a navegação do app

**Objetivo:** depois do login, o jogador vê uma tela inicial (hub) com atalhos para **Ranking**, **Catálogo** e **Jogar** (lobby). Neste tutorial você também cria o `AppDependencies`, o lugar único onde as implementações são montadas para as próximas telas.

**Pré-requisitos (já existem no projeto):** login funcionando, `AuthSession`, `ApiClient`, `SessionRepositoryImpl` e os repositórios `*Impl` de game, catálogo e ranking.

**Resultado final:**

```text
lib/core/di/app_dependencies.dart
lib/features/home/presentation/home_page.dart   (já existe uma versão provisória)
```

---

## Passo 1: entender o problema do `main.dart`

Hoje o `main.dart` monta tudo o que o login precisa. Se cada nova tela pedir mais 5 objetos, o `main` vira uma bagunça. A solução é um objeto que **cria e guarda** as dependências uma única vez (o *composition root*).

Regra que você vai seguir: **as telas nunca criam repositórios**. Elas recebem casos de uso ou controllers já prontos.

## Passo 2: criar o `AppDependencies`

Crie `lib/core/di/app_dependencies.dart`:

```dart
import '../network/api_client.dart';
import '../../features/auth/data/repositories/session_repository_impl.dart';
import '../../features/catalog/data/repositories/card_catalog_repository_impl.dart';
import '../../features/catalog/data/repositories/puzzle_catalog_repository_impl.dart';
import '../../features/catalog/data/repositories/skill_catalog_repository_impl.dart';
import '../../features/catalog/domain/usecases/list_cards_usecase.dart';
import '../../features/catalog/domain/usecases/list_puzzles_usecase.dart';
import '../../features/catalog/domain/usecases/list_skills_usecase.dart';
import '../../features/game/data/repositories/game_repository_impl.dart';
import '../../features/game/domain/repositories/game_repository.dart';
import '../../features/ranking/data/repositories/ranking_repository_impl.dart';
import '../../features/ranking/domain/usecases/get_ranking_usecase.dart';

/// Cria cada implementacao uma unica vez e a entrega pronta as telas.
final class AppDependencies {
  AppDependencies({required this.api, required this.sessions});

  final ApiClient api;
  final SessionRepositoryImpl sessions;

  // Repositorios (data)
  late final GameRepository gameRepository = GameRepositoryImpl(api);

  // Casos de uso (domain)
  late final getRanking = GetRankingUseCase(RankingRepositoryImpl(api));
  late final listCards = ListCardsUseCase(CardCatalogRepositoryImpl(api));
  late final listSkills = ListSkillsUseCase(SkillCatalogRepositoryImpl(api));
  late final listPuzzles = ListPuzzlesUseCase(PuzzleCatalogRepositoryImpl(api));
}
```

> `late final` cria o objeto só no primeiro uso. Se ninguém abrir o ranking, ele nunca é criado.

Os casos de uso da partida (`CreateGameUseCase`, `PlayCardUseCase` etc.) serão adicionados nos tutoriais de **lobby** e **game**, junto de `gameRepository`.

## Passo 3: usar o `AppDependencies` no `main.dart`

Troque a criação solta de objetos por:

```dart
late final AppDependencies _deps;

@override
void initState() {
  super.initState();
  final sessions = const SessionRepositoryImpl();
  final api = ApiClient(
    tokenProvider: () async => (await sessions.getCurrentSession())?.token,
    onUnauthorized: _logout,
  );
  _deps = AppDependencies(api: api, sessions: sessions);
  _login = LoginUseCase(AuthRepositoryImpl(api), sessions);
  ...
}
```

E passe `_deps` para a `HomePage`:

```dart
home = HomePage(session: _session!, deps: _deps, onLogout: _logout);
```

## Passo 4: desenhar a Home

A Home só mostra dados da sessão e botões de navegação. Ela **não** tem lógica de negócio, então não precisa de controller.

Edite `home_page.dart`:

```dart
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.deps,
    required this.onLogout,
  });

  final AuthSession session;
  final AppDependencies deps;
  final VoidCallback onLogout;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ola, ${session.user.nickname}'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Seus pontos de ranking'),
              trailing: Text('${session.user.rankingPoints}'),
            ),
          ),
          _MenuTile(
            icon: Icons.play_arrow,
            label: 'Jogar',
            onTap: () => _open(context, /* LobbyPage(...) - tutorial do lobby */ const SizedBox()),
          ),
          _MenuTile(
            icon: Icons.leaderboard,
            label: 'Ranking',
            onTap: () => _open(context, /* RankingPage(...) - tutorial do ranking */ const SizedBox()),
          ),
          _MenuTile(
            icon: Icons.style,
            label: 'Catalogo',
            onTap: () => _open(context, /* CatalogPage(...) - tutorial do catalogo */ const SizedBox()),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
```

Os `SizedBox()` são marcadores. Conforme você fizer cada tutorial, troque-os pela página real, criando o controller na hora de navegar:

```dart
onTap: () => _open(
  context,
  RankingPage(
    controller: RankingController(deps.getRanking),
    currentUserId: session.user.id,
  ),
),
```

## Passo 5: testar

1. `flutter run`, faça login e confira o nome e os pontos.
2. Toque nos atalhos: por enquanto abrem uma tela em branco com o botão de voltar.
3. Toque em **Sair**: deve voltar ao login e, ao reabrir o app, continuar no login.

## Dicas e armadilhas

- `Navigator.push` recebe um `builder`. Crie o controller dentro dele ou logo antes, nunca dentro do `build` de uma tela que reconstrói toda hora.
- O controller de uma tela deve ser liberado (`dispose`) quando a tela sai. Veja o tutorial do ranking para o padrão.
- A `HomePage` é `StatelessWidget` porque não guarda estado próprio.

## Exercícios

1. Mostre o `rankingPoints` atualizado: ao voltar do ranking, o valor ainda é o do login. Como buscar o usuário novamente? (Dica: pense em qual endpoint devolve o ranking.)
2. Troque a lista por um `GridView` de 2 colunas.
3. Adicione uma confirmação ("Deseja sair?") antes de `onLogout`.
