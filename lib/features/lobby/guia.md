# Guia do Lobby (passo a passo)

Neste guia você cria o **Lobby**: criar uma partida, entrar por código e esperar na sala de espera. Segue o padrão da feature Auth: **state → controller → page**. Leia antes o [tutorial de presentation do Auth](../auth/presentation/index.md) e, para a sala de espera, o [guia do Game](../game/guia.md), porque os dois compartilham o `GameController`.

## O fluxo

A API devolve um `GameState` ao **criar** (`POST /games`) ou **entrar** (`POST /games/access`). Na sala de espera, `GET /games/{id}/state` atualiza a lista de jogadores. O host inicia com `POST /games/{id}/start` ou cancela com `POST /games/{id}/cancel`.

```text
LobbyPage -> LobbyController -> CreateGameUseCase / AccessGameUseCase
                 |
                 +-> LobbyState.success(GameState) -> rota da partida
                                                        |-> WaitingRoomPage (aguardandoJogadores)
                                                        +-> GamePage        (demais fases)
```

Não existe endpoint para **listar salas** nem para **sair** individualmente de uma partida. Não invente esses fluxos.

## O que já existe (não recrie)

O domain e a data do Lobby já estão prontos na feature `game`: `GameState`, `GamePlayer`, `CreateGameInput`, `GameRepositoryImpl` e os casos de uso `CreateGameUseCase`, `AccessGameUseCase`, `GetGameStateUseCase`, `StartGameUseCase` e `CancelGameUseCase`. Falta só a **presentation**.

## Estrutura de pastas

```text
lib/features/lobby/presentation/
  state/        lobby_state.dart          <- retrato da tela de entrada
  controllers/  lobby_controller.dart     <- criar / entrar
  pages/        lobby_page.dart           <- menu: criar ou entrar
                create_game_page.dart     <- formulário de criação
                game_room_page.dart       <- rota da partida (dona do GameController)
                waiting_room_page.dart    <- lista de jogadores, iniciar, cancelar
```

Ordem de trabalho: state, controller, `LobbyPage`, `CreateGamePage`, `GameRoomPage`, `WaitingRoomPage` e, por fim, o `main.dart`.

O `GameController` (polling e ações da partida) é criado no **Passo 1 do guia do Game**. Faça-o antes do Passo 5 deste guia.

---

## Passo 1: o State

Arquivo: `state/lobby_state.dart`

### 1.1 O que a tela de entrada precisa saber

- `status`: `idle`, `loading`, `success` ou `failure`;
- `game`: o `GameState` devolvido pela API (só existe em `success`);
- `error`: a falha, só em `failure`.

### 1.2 Escreva o arquivo

```dart
import '../../../../core/error/app_exception.dart';
import '../../../game/domain/entities/game_state.dart';

enum LobbyStatus { idle, loading, success, failure }

final class LobbyState {
  final LobbyStatus status;
  final GameState? game;
  final AppException? error;

  const LobbyState._({required this.status, this.game, this.error});

  const LobbyState.idle() : this._(status: LobbyStatus.idle);
  const LobbyState.loading() : this._(status: LobbyStatus.loading);
  const LobbyState.success(GameState game)
      : this._(status: LobbyStatus.success, game: game);
  const LobbyState.failure(AppException error)
      : this._(status: LobbyStatus.failure, error: error);

  bool get isLoading => status == LobbyStatus.loading;
}
```

### 1.3 Por que é assim

| Estado | Quando | O que a tela mostra |
|---|---|---|
| `idle` | tela aberta | botões **Criar partida** e **Entrar** |
| `loading` | esperando a API | botões desabilitados |
| `success` | partida criada/encontrada | (abre a rota da partida) |
| `failure` | erro | mensagem em vermelho perto da ação |

Os construtores nomeados impedem estados impossíveis, como `success` sem `game`.

✅ **Confira:** o arquivo não importa Flutter.

---

## Passo 2: o Controller

Arquivo: `controllers/lobby_controller.dart`

### 2.1 Responsabilidade

Receber as duas ações do menu (`create` e `access`), chamar o caso de uso e traduzir o resultado em `LobbyState`. Não usa `BuildContext`, não faz HTTP e **não navega**.

### 2.2 Escreva o arquivo

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../game/domain/entities/game_state.dart';
import '../../../game/domain/inputs/create_game_input.dart';
import '../../../game/domain/usecases/access_game_usecase.dart';
import '../../../game/domain/usecases/create_game_usecase.dart';
import '../state/lobby_state.dart';

class LobbyController extends ChangeNotifier {
  final CreateGameUseCase _create;
  final AccessGameUseCase _access;

  LobbyController({
    required CreateGameUseCase create,
    required AccessGameUseCase access,
  })  : _create = create,
        _access = access;

  LobbyState _state = const LobbyState.idle();
  LobbyState get state => _state;

  Future<void> create(CreateGameInput input) {
    if (!input.isValid) {                                        // 2
      _emit(const LobbyState.failure(BadRequestException(
        message: 'Confira os campos: há valores fora do permitido.',
      )));
      return Future.value();
    }
    return _run(() => _create(input));
  }

  Future<void> access(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 6) {                                // 2
      _emit(const LobbyState.failure(BadRequestException(
        message: 'O código da partida tem 6 caracteres.',
      )));
      return Future.value();
    }
    return _run(() => _access(normalized));
  }

  /// Volta ao estado inicial depois que a tela já usou o resultado.
  void reset() => _emit(const LobbyState.idle());

  Future<void> _run(Future<GameState> Function() action) async {
    if (_state.isLoading) return;                                // 1
    _emit(const LobbyState.loading());                           // 3
    try {
      _emit(LobbyState.success(await action()));                 // 4
    } on AppException catch (e) {
      _emit(LobbyState.failure(e));                              // 5
    } catch (e) {
      _emit(LobbyState.failure(UnexpectedException(cause: e)));
    }
  }

  void _emit(LobbyState state) {
    _state = state;
    notifyListeners();                                           // 6
  }
}
```

### 2.3 Passo a passo

1. **Evita duplo toque:** se já está carregando, ignora.
2. **Valida antes da rede:** `CreateGameInput.isValid` (regras do domain) e o tamanho do código. A API continua sendo a validação definitiva; se ela responder `400`, a mensagem aparece para o jogador.
3. **Emite `loading`.**
4. **Chama o caso de uso** e emite `success` com o `GameState`.
5. **Traduz exceções em estado:** `AppException` vira `failure` com a mensagem da API; o resto vira `UnexpectedException`.
6. **`notifyListeners()`** avisa a tela.

O `reset()` existe para a tela limpar o `success` depois de navegar. Sem ele, o estado ficaria em `success` ao voltar do jogo.

✅ **Confira:** só `foundation.dart`, nenhuma importação de `material.dart`.

---

## Passo 3: a `LobbyPage` (menu)

Arquivo: `pages/lobby_page.dart`

### 3.1 Responsabilidade

Mostrar os dois caminhos (**Criar partida** e **Entrar por código**) e, quando o estado virar `success`, avisar o pai com `onGameReady`. Quem navega para a partida é o pai.

### 3.2 Construtor e ciclo de vida

```dart
import 'package:flutter/material.dart';

import '../../../game/domain/entities/game_state.dart';
import '../../../game/domain/inputs/create_game_input.dart';
import '../controllers/lobby_controller.dart';
import '../state/lobby_state.dart';
import 'create_game_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({
    super.key,
    required this.controller,
    required this.onGameReady,
  });

  final LobbyController controller;
  final void Function(GameState game) onGameReady;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.controller.dispose();
    _code.dispose();
    super.dispose();
  }
  ...
}
```

### 3.3 Reagir ao sucesso

```dart
void _onChange() {
  final state = widget.controller.state;
  if (state.status == LobbyStatus.success && state.game != null) {
    widget.onGameReady(state.game!);
    widget.controller.reset();
  }
}
```

Desenhar (`builder`) e **reagir** (navegar) são coisas diferentes: o `addListener` cuida da reação.

### 3.4 Ações dos botões

```dart
void _join() => widget.controller.access(_code.text);

Future<void> _create() async {
  final input = await Navigator.of(context).push<CreateGameInput>(
    MaterialPageRoute(builder: (_) => const CreateGamePage()),
  );
  if (input == null || !mounted) return;     // depois de await, cheque mounted
  widget.controller.create(input);
}
```

O formulário **não chama a API**: ele só devolve um `CreateGameInput` com `Navigator.pop`. Quem chama a API é o controller.

### 3.5 O `build`

```dart
@override
Widget build(BuildContext context) {
  return SafeArea(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton(
              onPressed: state.isLoading ? null : _create,
              child: const Text('Criar partida'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _code,
              enabled: !state.isLoading,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _join(),
              decoration: const InputDecoration(
                labelText: 'Código da partida',
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: state.isLoading ? null : _join,
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
            if (state.status == LobbyStatus.failure) ...[
              const SizedBox(height: 12),
              Text(
                state.error?.message ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    ),
  );
}
```

- Se a página for filha da dock, devolva **só o conteúdo**: `Scaffold` e `NavigationBar` ficam no contêiner (veja a [dock](../../../guia_dock.md)).
- `textCapitalization` só muda o teclado; quem normaliza o código é o controller.
- Mostre o erro **perto da ação**, como acima.

✅ **Confira:** a página não importa nada de `data/`.

---

## Passo 4: a `CreateGamePage` (formulário)

Arquivo: `pages/create_game_page.dart`

### 4.1 Regras dos campos (as mesmas de `CreateGameInput.isValid` e da API)

| Campo | Regra |
|---|---|
| Nome | obrigatório, até 60 caracteres |
| Jogadores (`maxPlayers`) | 2 a 6 |
| Cartas iniciais (`initialCards`) | 1 a 10 |
| Recompensa da rodada (`roundReward`) | maior ou igual a 0 |
| Recompensa de mão vazia (`emptyHandReward`) | maior ou igual a 0 |
| Preço do troféu (`trophyPrice`) | maior que 0 |

### 4.2 Escreva o arquivo

```dart
import 'package:flutter/material.dart';

import '../../../game/domain/inputs/create_game_input.dart';

class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});

  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _roundReward = TextEditingController(text: '10');
  final _emptyHandReward = TextEditingController(text: '5');
  final _trophyPrice = TextEditingController(text: '30');
  int _maxPlayers = 4;
  int _initialCards = 3;

  @override
  void dispose() {
    _name.dispose();
    _roundReward.dispose();
    _emptyHandReward.dispose();
    _trophyPrice.dispose();
    super.dispose();
  }

  String? _nonNegative(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 0) ? 'Informe um número maior ou igual a 0' : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = CreateGameInput(
      name: _name.text.trim(),
      maxPlayers: _maxPlayers,
      initialCards: _initialCards,
      roundReward: int.parse(_roundReward.text),
      emptyHandReward: int.parse(_emptyHandReward.text),
      trophyPrice: int.parse(_trophyPrice.text),
    );
    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova partida')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome da partida',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe o nome da partida'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _maxPlayers,
                decoration: const InputDecoration(
                  labelText: 'Máximo de jogadores',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final n in List.generate(5, (i) => i + 2))
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) => setState(() => _maxPlayers = v ?? _maxPlayers),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _initialCards,
                decoration: const InputDecoration(
                  labelText: 'Cartas iniciais',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final n in List.generate(10, (i) => i + 1))
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) =>
                    setState(() => _initialCards = v ?? _initialCards),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roundReward,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Recompensa por rodada',
                  border: OutlineInputBorder(),
                ),
                validator: _nonNegative,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emptyHandReward,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Recompensa por mão vazia',
                  border: OutlineInputBorder(),
                ),
                validator: _nonNegative,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trophyPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Preço do troféu',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n <= 0)
                      ? 'Informe um número maior que 0'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Criar')),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 4.3 Pontos de atenção

- Os `validator` dão feedback imediato no campo, sem rede. A regra oficial é `CreateGameInput.isValid`, reforçada no `LobbyController.create`.
- A página tem `Scaffold` próprio porque é uma rota empilhada sobre o menu.
- Em versões antigas do Flutter, `DropdownButtonFormField` usa `value:` em vez de `initialValue:`. Use o que o seu SDK aceitar.

✅ **Confira:** com o campo vazio ou fora da regra, o formulário mostra o erro e **não** fecha.

---

## Passo 5: a rota da partida (`GameRoomPage`)

Arquivo: `pages/game_room_page.dart`

### 5.1 Responsabilidade

Ser **dona do `GameController`**: cria o polling ao abrir e libera ao fechar. Assim, a troca da sala de espera para o jogo não perde o controller nem duplica o polling. Ela decide qual tela mostrar pela `phase`.

### 5.2 Escreva o arquivo

```dart
import 'package:flutter/material.dart';

import '../../../game/domain/enums/game_phase.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../../../game/presentation/pages/game_page.dart';
import 'waiting_room_page.dart';

class GameRoomPage extends StatefulWidget {
  const GameRoomPage({
    super.key,
    required this.controller,
    required this.myNickname,
    required this.onExit,
  });

  final GameController controller;
  final String myNickname;
  final VoidCallback onExit;

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.startPolling();
  }

  @override
  void dispose() {
    widget.controller.dispose();      // cancela o Timer de polling
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final phase = widget.controller.state.phase;
        return switch (phase) {
          GamePhase.aguardandoJogadores => Scaffold(
              appBar: AppBar(title: const Text('Sala de espera')),
              body: WaitingRoomPage(
                controller: widget.controller,
                myNickname: widget.myNickname,
                onLeave: widget.onExit,
              ),
            ),
          _ => GamePage(
              controller: widget.controller,
              myNickname: widget.myNickname,
              onExit: widget.onExit,
            ),
        };
      },
    );
  }
}
```

### 5.3 Regras

- **Só esta rota** chama `controller.dispose()`. `WaitingRoomPage` e `GamePage` **não** devem descartá-lo. Se o seu `GamePage` (do guia do Game) tem `widget.controller.dispose()` no `dispose`, remova essa linha.
- **Sem `Scaffold` aninhado:** a sala de espera vem embrulhada em `Scaffold` aqui (ela devolve só o corpo); `GamePage` traz o dela.
- Os construtores são ilustrativos: ajuste aos que você definiu no guia do Game.

✅ **Confira:** há um único ponto que cria o polling (`initState`) e um único que o encerra (`dispose`).

---

## Passo 6: a `WaitingRoomPage`

Arquivo: `pages/waiting_room_page.dart`

### 6.1 Responsabilidade

Mostrar código, nome, contagem e lista de jogadores; oferecer **Iniciar** e **Cancelar** ao host e **Voltar à Home** ao convidado. Ela **escuta** o controller; nunca faz requisição em `build`.

### 6.2 Como saber se você é o host

Ache o seu `GamePlayer` pelo **apelido da sessão** e leia `player.host`. **Não** compare `GamePlayer.id` com `PlayerUser.id`: são IDs diferentes.

### 6.3 Escreva o arquivo

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game/domain/entities/game_player.dart';
import '../../../game/presentation/controllers/game_controller.dart';

class WaitingRoomPage extends StatelessWidget {
  const WaitingRoomPage({
    super.key,
    required this.controller,
    required this.myNickname,
    required this.onLeave,
  });

  final GameController controller;
  final String myNickname;
  final VoidCallback onLeave;

  GamePlayer? _me(List<GamePlayer> players) {
    for (final p in players) {
      if (p.nickname == myNickname) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;
          final me = _me(state.players);
          final isHost = me?.host ?? false;
          final canStart = state.players.length >= 2 && !controller.busy;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(state.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Código: ${state.code}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  IconButton(
                    tooltip: 'Copiar código',
                    icon: const Icon(Icons.copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: state.code)),
                  ),
                ],
              ),
              Text(
                '${state.players.length}/${state.settings.maxPlayers} jogadores',
              ),
              const Divider(height: 32),
              for (final p in state.players)
                ListTile(
                  leading: Icon(p.host ? Icons.star : Icons.person),
                  title: Text(
                    p.nickname == myNickname ? '${p.nickname} (você)' : p.nickname,
                  ),
                  subtitle: p.host ? const Text('Host') : null,
                ),
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.error!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (isHost) ...[
                FilledButton(
                  onPressed: canStart ? controller.start : null,
                  child: const Text('Iniciar partida'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.busy ? null : controller.cancel,
                  child: const Text('Cancelar partida'),
                ),
              ] else ...[
                const Text('Aguardando o host iniciar a partida...'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onLeave,
                  child: const Text('Voltar à Home'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
```

### 6.4 Regras dessa tela

- **Iniciar só para o host.** `players.length >= 2` é só conforto de UI; quem valida é a API (`400`/`409` com a mensagem).
- **Cancelar só para o host.** Quando a API aceita, o `GameController` recebe `phase == cancelado`. A `GameRoomPage` troca para `GamePage`, que deve mostrar "Partida cancelada" e chamar `onExit`. Se preferir, trate o `cancelado` na rota antes do `switch`.
- **Convidado:** **Voltar à Home** apenas fecha a tela local. Não existe endpoint de saída individual: o jogador continua na lista até o host cancelar. Diga isso ao usuário.
- **Ao iniciar:** `start()` aplica o `GameState` retornado. Quando `phase` vira `emAndamento`, a `GameRoomPage` mostra a `GamePage` sozinha, sem navegar.
- `409`: o `GameController` já mostra a mensagem e consulta o estado de novo (veja o guia do Game). Em `401`, o `ApiClient` encerra a sessão pelo callback do `main.dart`.

✅ **Confira:** a página não tem `initState`, nem `Timer`, nem chamadas em `build`.

---

## Passo 7: montar no `main.dart` (composition root)

### 7.1 Casos de uso (uma vez)

No mesmo lugar onde o `main.dart` cria `_api`:

```dart
final gameRepository = GameRepositoryImpl(_api);
final createGame = CreateGameUseCase(gameRepository);
final accessGame = AccessGameUseCase(gameRepository);
final getGameState = GetGameStateUseCase(gameRepository);
final startGame = StartGameUseCase(gameRepository);
final cancelGame = CancelGameUseCase(gameRepository);
```

Guarde como **campos** do `State` (ou em um objeto de dependências). Variáveis locais recriadas em `build` seriam refeitas a cada redesenho. O `PlayCardUseCase`, `AnswerPuzzleUseCase`, `BuyTrophyUseCase` e `ReadyForNextRoundUseCase` também usam o **mesmo** `gameRepository` (veja o guia do Game).

### 7.2 A aba do Lobby

Crie o `LobbyController` **fora do `build`** (por exemplo, no `initState` do contêiner):

```dart
LobbyPage(
  controller: LobbyController(create: createGame, access: accessGame),
  onGameReady: _openGame,
)
```

### 7.3 Abrir a rota da partida

```dart
void _openGame(GameState initial) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GameRoomPage(
        controller: GameController(
          initial: initial,
          getState: getGameState,
          startGame: startGame,
          playCard: playCard,
          answerPuzzle: answerPuzzle,
          buyTrophy: buyTrophy,
          ready: readyForNextRound,
          cancelGame: cancelGame,
        ),
        myNickname: _session.user.nickname,
        onExit: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ),
  );
}
```

Os nomes dos parâmetros seguem o `GameController` do guia do Game. O `GameController` é criado **dentro do `builder`** da rota, e é a `GameRoomPage` que o descarta. Como o `builder` pode rodar de novo, crie o controller antes do `push` se notar que ele é recriado (por exemplo, depois de girar a tela).

✅ **Confira:** o `ApiClient` só é criado em `main.dart`. O token de sessão é anexado por ele.

---

## Passo 8: verificar com dois usuários

1. **A** cria a partida e vê o código e a própria linha como host.
2. **B** entra pelo código; **A** o vê na sala em cerca de 1 segundo.
3. **B** não vê **Iniciar**; **A** inicia com pelo menos dois jogadores.
4. Os dois vão para a mesma partida, **sem polling duplicado** e sem perder o controller.
5. Ao fechar a rota, confirme que o `Timer` foi cancelado (nenhuma requisição periódica depois).
6. Erros: código inexistente (`404`), iniciar sozinho (`400`/`409`), nome vazio no formulário, tocar duas vezes em **Entrar** (só uma requisição).
7. **A** cancela a partida: **B** vê "Partida cancelada" e consegue voltar à Home.

## Armadilhas comuns

- Comparar `GamePlayer.id` com `PlayerUser.id` para descobrir o host (use o apelido).
- Criar `LobbyController` ou `GameController` dentro de `build`.
- Dois donos para o `GameController` (a rota **e** a página chamando `dispose`).
- Esquecer `mounted` depois de um `await` antes de usar `context`.
- Esquecer `controller.reset()` e o lobby ficar preso em `success` ao voltar.
- Inventar botão de "sair da partida" ou "listar salas": a API não tem esses endpoints.
- Confiar no botão desabilitado como regra: quem valida é a API.

## Exercícios

1. Escreva um teste do `LobbyController` com casos de uso falsos: verifique `loading` e depois `success`, e `loading` e depois `failure`.
2. Mostre as configurações da partida (`state.settings`) na sala de espera.
3. Mostre quem está pronto (`GamePlayer.ready`) com um ícone.
4. Trate `ConflictException` ao iniciar recarregando o estado antes de mostrar o erro (se o `GameController` ainda não fizer isso).
5. Mostre um `SnackBar` "Código copiado" ao tocar no botão de copiar.

Continue no [guia do Game](../game/guia.md) e veja a [dock](../../../guia_dock.md) para abrir o Lobby a partir do app.
