# Tutorial: criando o Lobby (criar, entrar e sala de espera)

**Objetivo:** o jogador pode **criar uma partida**, **entrar por código de 6 caracteres** e esperar na **sala de espera** até o host iniciar.

**Endpoints usados:** `POST /games`, `POST /games/access`, `GET /games/{id}/state`, `POST /games/{id}/start`, `POST /games/{id}/cancel`.

**Pré-requisitos (já existem):** `GameState`, `CreateGameInput`, `GameRepository` e `GameRepositoryImpl`, e os casos de uso `CreateGameUseCase`, `AccessGameUseCase`, `StartGameUseCase`, `GetGameStateUseCase` e `CancelGameUseCase`.

**Arquivos que você vai criar:**

```text
lib/features/lobby/presentation/
  controllers/lobby_controller.dart      <- criar / entrar
  pages/lobby_page.dart                  <- menu: criar ou entrar
  pages/create_game_page.dart            <- formulario
  pages/waiting_room_page.dart           <- lista de jogadores + iniciar
lib/features/game/presentation/controllers/game_controller.dart
                                          <- compartilhado (veja tutorial do game)
```

A sala de espera usa o mesmo `GameController` da partida (polling do estado), então faça primeiro o **Passo 1 do tutorial do game** ou copie-o de lá.

---

## Como o lobby funciona (leia antes de codar)

1. Criar ou entrar devolve um `GameState` com `phase == aguardandoJogadores`.
2. Na sala de espera, o app pergunta o estado a cada segundo (polling) e mostra quem entrou.
3. O **host** vê o botão "Iniciar" (a API exige 2 ou mais jogadores).
4. Quando `phase` vira `emAndamento`, todos navegam para a tela da partida.

Regras de ouro: o app **não** decide quem é host nem quando a partida começa. Ele só lê `GamePlayer.host` e `GameState.phase`.

## Passo 1: registrar os casos de uso

No `AppDependencies` (tutorial da Home), adicione:

```dart
late final createGame = CreateGameUseCase(gameRepository);
late final accessGame = AccessGameUseCase(gameRepository);
late final startGame = StartGameUseCase(gameRepository);
late final getGameState = GetGameStateUseCase(gameRepository);
late final cancelGame = CancelGameUseCase(gameRepository);
```

## Passo 2: o controller de criar/entrar

Ele só cuida de duas ações e devolve o `GameState` para a tela navegar.

`controllers/lobby_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../game/domain/entities/game_state.dart';
import '../../../game/domain/inputs/create_game_input.dart';
import '../../../game/domain/usecases/access_game_usecase.dart';
import '../../../game/domain/usecases/create_game_usecase.dart';

class LobbyController extends ChangeNotifier {
  LobbyController({required CreateGameUseCase create, required AccessGameUseCase access})
      : _create = create,
        _access = access;

  final CreateGameUseCase _create;
  final AccessGameUseCase _access;

  bool loading = false;
  AppException? error;

  Future<GameState?> createGame(CreateGameInput input) =>
      _run(() => _create(input));

  Future<GameState?> accessGame(String code) => _run(() => _access(code));

  Future<GameState?> _run(Future<GameState> Function() action) async {
    if (loading) return null;
    loading = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } on AppException catch (e) {
      error = e;
    } catch (e) {
      error = UnexpectedException(cause: e);
    } finally {
      loading = false;
      notifyListeners();
    }
    return null;
  }
}
```

O método devolve `GameState?`: `null` significa falha (e `error` explica). A tela decide navegar quando recebe um estado.

## Passo 3: a tela do menu

`pages/lobby_page.dart`: dois botões e um campo de código.

```dart
class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key, required this.controller, required this.onGameReady});

  final LobbyController controller;
  final void Function(GameState state) onGameReady;   // quem navega e o pai

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _code = TextEditingController();

  Future<void> _join() async {
    final state = await widget.controller.accessGame(_code.text);
    if (state != null && mounted) widget.onGameReady(state);
  }

  Future<void> _create() async {
    final input = await Navigator.of(context).push<CreateGameInput>(
      MaterialPageRoute(builder: (_) => const CreateGamePage()),
    );
    if (input == null) return;
    final state = await widget.controller.createGame(input);
    if (state != null && mounted) widget.onGameReady(state);
  }

  @override
  void dispose() {
    _code.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jogar')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return ListView(padding: const EdgeInsets.all(16), children: [
            FilledButton(
              onPressed: c.loading ? null : _create,
              child: const Text('Criar partida'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _code,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codigo da partida',
                border: OutlineInputBorder(),
              ),
            ),
            OutlinedButton(
              onPressed: c.loading ? null : _join,
              child: const Text('Entrar'),
            ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(c.error!.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]);
        },
      ),
    );
  }
}
```

Atenção ao `mounted`: depois de um `await`, a tela pode ter sido fechada. Usar `context` sem checar dá erro.

## Passo 4: o formulário de criação

`pages/create_game_page.dart` devolve um `CreateGameInput` com `Navigator.pop(input)`. Ele **não chama a API**: só coleta e valida os dados.

Regras (as mesmas de `CreateGameInput.isValid`): nome até 60 caracteres; jogadores 2 a 6; cartas iniciais 1 a 10; recompensas maiores ou iguais a 0; preço do troféu maior que 0.

```dart
class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});
  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  final _name = TextEditingController();
  int _maxPlayers = 4;
  int _initialCards = 3;
  final _roundReward = TextEditingController(text: '10');
  final _emptyHandReward = TextEditingController(text: '5');
  final _trophyPrice = TextEditingController(text: '30');
  String? _error;

  void _submit() {
    final input = CreateGameInput(
      name: _name.text,
      maxPlayers: _maxPlayers,
      initialCards: _initialCards,
      roundReward: int.tryParse(_roundReward.text) ?? -1,
      emptyHandReward: int.tryParse(_emptyHandReward.text) ?? -1,
      trophyPrice: int.tryParse(_trophyPrice.text) ?? 0,
    );
    if (!input.isValid) {
      setState(() => _error = 'Confira os campos: valores fora do permitido.');
      return;
    }
    Navigator.of(context).pop(input);
  }

  // build: TextField do nome, Slider/Dropdown para maxPlayers (2-6) e
  // initialCards (1-10), TextField numerico para as tres recompensas e
  // o botao "Criar" que chama _submit. Mostre _error quando existir.
}
```

O `build` fica como exercício guiado: use `DropdownButtonFormField<int>` com `List.generate(5, (i) => i + 2)` para os jogadores.

## Passo 5: a sala de espera

Ela mostra código, jogadores e botões. Os dados vêm do `GameController` (polling).

```dart
class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({
    super.key,
    required this.controller,
    required this.myNickname,
    required this.onStarted,
    required this.onLeave,
  });

  final GameController controller;            // ja criado com o estado inicial
  final String myNickname;
  final void Function(GameState state) onStarted;
  final VoidCallback onLeave;

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}
```

No `initState`: `widget.controller.startPolling()` e `addListener(_onChange)`. No `_onChange`:

```dart
void _onChange() {
  final s = widget.controller.state;
  if (s == null) return;
  if (s.phase == GamePhase.emAndamento) {
    widget.controller.removeListener(_onChange);
    widget.onStarted(s);            // navega para a partida
  } else if (s.phase == GamePhase.cancelado) {
    widget.onLeave();
  }
}
```

No `build`:

```dart
final state = widget.controller.state!;
final me = state.players.firstWhere((p) => p.nickname == widget.myNickname);

Column(children: [
  Text('Codigo: ${state.code}', style: Theme.of(context).textTheme.headlineMedium),
  Text('${state.players.length}/${state.settings.maxPlayers} jogadores'),
  for (final p in state.players)
    ListTile(
      leading: Icon(p.host ? Icons.star : Icons.person),
      title: Text(p.nickname),
      subtitle: p.host ? const Text('Host') : null,
    ),
  if (me.host)
    FilledButton(
      onPressed: state.players.length >= 2 ? widget.controller.start : null,
      child: const Text('Iniciar partida'),
    ),
  if (me.host)
    TextButton(onPressed: widget.controller.cancel, child: const Text('Cancelar partida')),
])
```

Por que achamos "eu" pelo `nickname`? O `GameState` não traz o id do usuário, e `GamePlayer.id` é diferente de `PlayerUser.id`. O apelido é único (o login cria uma conta por apelido), então serve para identificar você na lista.

## Passo 6: ligar tudo (navegação)

Onde cria a `LobbyPage` (na Home):

```dart
LobbyPage(
  controller: LobbyController(create: deps.createGame, access: deps.accessGame),
  onGameReady: (state) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => WaitingRoomPage(
        controller: GameController(/* casos de uso + state inicial */),
        myNickname: session.user.nickname,
        onStarted: (s) { /* abrir a GamePage - tutorial do game */ },
        onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    ),
  ),
),
```

## Passo 7: testar (com dois jogadores)

1. Faça login com dois apelidos em dois emuladores, ou um no navegador e outro no celular.
2. Jogador A cria a partida e anota o código.
3. Jogador B entra pelo código: a lista de A deve atualizar em cerca de 1 segundo.
4. A inicia. Os dois devem sair da sala de espera.
5. Teste os erros: código inexistente (404), iniciar sozinho (a API responde 400/409 com a mensagem).

## Armadilhas comuns

- Código em minúsculas: o repositório já converte para maiúsculas, mas mostre o teclado em caixa alta.
- Esquecer de parar o polling ao sair da tela (veja o tutorial do game).
- Confiar no botão desabilitado como regra: `players.length >= 2` é só conforto de UI. Quem valida é a API.

## Exercícios

1. Mostre um botão "Copiar código" (`Clipboard.setData`).
2. Mostre as configurações da partida (`state.settings`) na sala de espera.
3. Mostre quem está pronto (`GamePlayer.ready`) com um ícone.
4. Trate `ConflictException` no `start()` recarregando o estado antes de mostrar o erro.
