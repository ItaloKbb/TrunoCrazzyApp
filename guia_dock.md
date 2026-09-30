# Guia: criar a dock de navegação do app

## Resultado esperado

Depois do login, uma barra inferior permite alternar entre **Home**, **Jogar** (Lobby), **Catálogo**, **Ranking** e **Perfil**. A partida aberta pelo Lobby ocupa uma rota própria, sem a dock, para evitar trocas de aba durante uma jogada. O login também fica fora da dock.

Este guia se aplica ao código atual: `lib/main.dart` escolhe entre login e `HomePage`; `HomePage` e `CatalogoPage` ainda possuem `Scaffold` próprio; Lobby, Ranking e Profile ainda precisam das páginas dos guias de cada feature. Use `NavigationBar` do Material 3, já habilitado em `ThemeData`.

## 1. Escolha quem controla a navegação

Crie `lib/core/navigation/app_shell.dart`. `AppShell` é um `StatefulWidget` que recebe os corpos das abas já montados com a sessão, os casos de uso e o callback de logout. Ele guarda somente o índice selecionado. O `main.dart` continua responsável por autenticação: `_session == null` mostra `LoginPage`; sessão válida mostra `AppShell`.

Fluxo:

```text
main.dart (ApiClient + sessão)
├── LoginPage, quando não há sessão
└── AppShell, quando há sessão
    ├── Home
    ├── Lobby  ── abre rota de partida: sala de espera → Game
    ├── Catálogo
    ├── Ranking
    └── Perfil
```

`AppShell` é o único `Scaffold` da área principal e coloca `NavigationBar` em `bottomNavigationBar`. Transforme Home e Catálogo em corpos de aba, retirando seus `Scaffold`s internos; mantenha um `AppBar` no shell, com título que muda conforme a aba. Se precisar de uma tela de Catálogo independente fora da dock, extraia seu conteúdo para um widget reutilizável e envolva esse widget em um `Scaffold` apenas naquela rota.

## 2. Implemente a estrutura da dock

Este exemplo mostra o núcleo de `app_shell.dart`. A Home é criada com callbacks que selecionam abas; os outros quatro corpos são widgets criados com as dependências do `main.dart`. Os guias de cada feature explicam como montá-los.

```dart
import 'package:flutter/material.dart';

typedef HomeBodyBuilder = Widget Function(
  VoidCallback onPlay,
  VoidCallback onCatalog,
  VoidCallback onRanking,
);

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.homeBuilder,
    required this.lobbyBody,
    required this.catalogBody,
    required this.rankingBody,
    required this.profileBody,
  });

  final HomeBodyBuilder homeBuilder;
  final Widget lobbyBody;
  final Widget catalogBody;
  final Widget rankingBody;
  final Widget profileBody;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;

  static const _titles = ['Home', 'Jogar', 'Catálogo', 'Ranking', 'Perfil'];

  void selectTab(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      widget.homeBuilder(
        () => selectTab(1),
        () => selectTab(2),
        () => selectTab(3),
      ),
      widget.lobbyBody,
      widget.catalogBody,
      widget.rankingBody,
      widget.profileBody,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selected])),
      body: IndexedStack(index: _selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Jogar'),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), label: 'Ranking'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}
```

`IndexedStack` mantém o estado de cada aba ao trocar de destino, como texto digitado no Lobby ou a lista já carregada no Ranking. Ele também monta os cinco filhos ao entrar na área autenticada. Se alguma aba fizer consulta em `initState`, ela poderá consultar a API antes de ser selecionada; para carregar só na primeira visita, crie as abas sob demanda ou passe um sinal de aba ativa ao controller. O essencial é não chamar uma API em `build`.

Para a Home selecionar uma aba sem ter acesso ao `State` privado do shell, `homeBuilder` recebe callbacks `onPlay`, `onCatalog` e `onRanking`. Na montagem, use `homeBuilder: (onPlay, onCatalog, onRanking) => HomePage(session: session, onPlay: onPlay, onCatalog: onCatalog, onRanking: onRanking)`, após adaptar a `HomePage` conforme o guia dela.

## 3. Ligue ao `main.dart` e à API

Mantenha a configuração de `_api` que já existe:

```dart
_api = ApiClient(
  tokenProvider: () async => (await _sessions.getCurrentSession())?.token,
  onUnauthorized: _logout,
);
```

Na ramificação `else` de `build`, onde hoje é criada a `HomePage`, monte `AppShell` com a sessão e os casos de uso. Reutilize `_api` para todos os repositórios:

```dart
final gameRepository = GameRepositoryImpl(_api);
final getRanking = GetRankingUseCase(RankingRepositoryImpl(_api));
final listCards = ListCardsUseCase(CardCatalogRepositoryImpl(_api));
```

Guarde esses objetos como campos `late final` em `_TrunoCrazyAppState` ou em um objeto de dependências criado em `initState`; o trecho acima mostra o relacionamento, não deve ser copiado para dentro de `build`. O `main.dart` já possui `_listCards`, que pode ser reutilizado. Entregue `getRanking` ao Ranking e ao Perfil; entregue os casos de uso de partida ao Lobby e à rota de Game. A UI chama casos de uso; somente os repositórios chamam `ApiClient`.

### Posse e descarte

- O shell vive enquanto houver sessão. Se ele criar controllers de abas, ele chama `dispose` neles quando for removido. Se cada página os criar, cada página faz o próprio `dispose`. Escolha um dono por controller.
- A rota de partida é dona do `GameController`. Ela inicia e cancela o polling, e chama `dispose` ao sair. A sala de espera e o Game só recebem esse mesmo controller.
- `onUnauthorized` ou o botão **Sair** limpam a sessão no `main.dart`. Também feche rotas empilhadas, inclusive a partida: trocar apenas o widget `home` do `MaterialApp` não garante que uma rota aberta com `Navigator.push` desapareça. Uma forma é definir `final _navigatorKey = GlobalKey<NavigatorState>();` no estado raiz, passá-la a `MaterialApp(navigatorKey: _navigatorKey, ...)` e, no fim de `_logout`, chamar `_navigatorKey.currentState?.popUntil((route) => route.isFirst)`. A rota fechada descarta seu `GameController` e cancela o polling.

## 4. Abra a partida fora da dock

Quando `CreateGameUseCase` ou `AccessGameUseCase` devolver um `GameState`, use `Navigator.push` a partir do Lobby para abrir a rota de partida. A rota mantém `GameController(initial: state, ...)` e escolhe o corpo pela fase: `aguardandoJogadores` mostra a sala de espera; `emAndamento` e fases posteriores mostram o Game. `Navigator.pop` volta ao shell na aba Jogar. Não represente uma partida como sexta aba, pois ela tem ciclo de vida próprio e polling contínuo.

## 5. Ordem prática para implementar

1. Crie `AppShell` com a barra e corpos provisórios simples; conecte-o à ramificação autenticada de `main.dart`.
2. Extraia o conteúdo de `HomePage` e `CatalogoPage` dos `Scaffold`s existentes; confira que há apenas uma barra inferior.
3. Ligue a aba Ranking ao `GetRankingUseCase` e a Perfil à sessão + ranking.
4. Ligue a aba Jogar ao Lobby; crie/acesse uma partida e abra a rota de Game.
5. Conecte os atalhos da Home a `selectTab` e o logout do Perfil ao `_logout` de `main.dart`.

Guias de cada tela: [Home](lib/features/home/guia.md), [Lobby](lib/features/lobby/guia.md), [Game](lib/features/game/guia.md), [Ranking](lib/features/ranking/guia.md) e [Profile](lib/features/profile/guia.md).

## 6. Confirme o comportamento

- Sem sessão, a dock não aparece. Após login, abre na Home; após logout ou `401`, volta ao login.
- Trocar de aba mantém formulário do Lobby e dados já carregados no Ranking.
- Home e Catálogo não mostram `Scaffold` ou `AppBar` duplicados.
- Abrir uma partida cobre a dock; voltar libera o polling e mostra a aba Jogar.
- As consultas usam o `API_BASE_URL` configurado no `ApiClient` (`--dart-define=API_BASE_URL=...` quando necessário) e o token da sessão.
