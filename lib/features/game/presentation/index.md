# Tutorial: criando a tela da Partida (Game)

**Objetivo:** a tela onde o jogo acontece: ver a vira, os jogadores, as jogadas da rodada, a sua mão, jogar uma carta, responder puzzles, comprar troféu, confirmar a próxima rodada e ver o vencedor.

**Endpoints usados:** `GET /games/{id}/state` (polling), `POST /games/{id}/plays`, `/puzzle-answers`, `/trophies`, `/ready`, `/cancel`.

**Pré-requisitos (já existem):** `GameState` e entidades filhas, os enums, `GameRepository`/`GameRepositoryImpl` e os casos de uso `GetGameStateUseCase`, `PlayCardUseCase`, `AnswerPuzzleUseCase`, `BuyTrophyUseCase`, `ReadyForNextRoundUseCase`, `CancelGameUseCase`, `StartGameUseCase`. Também o `CardTile` e as extensions de `card_labels.dart` (tutorial do catálogo).

**Arquivos que você vai criar:**

```text
lib/features/game/presentation/
  controllers/game_controller.dart
  pages/game_page.dart
  widgets/players_bar.dart
  widgets/table_plays.dart
  widgets/hand_view.dart
  widgets/puzzle_dialog.dart
```

---

## Regras que governam toda a tela (leia primeiro)

1. **A API é a fonte da verdade.** O app não calcula vencedor, manilha, turno, moedas ou skills.
2. **Toda ação devolve o `GameState` atualizado.** Substitua o estado local pelo retorno.
3. **Polling de ~1 segundo** com `GetGameStateUseCase`. Só publique o estado se `stateVersion` for maior que o atual.
4. **Só `handCardId` joga uma carta.** Nunca envie `catalogCardId`.
5. **A sua mão vem em `hand`.** Para os adversários existe só `handSize`.
6. **`currentPlayerId` é um `GamePlayer.id`**, não o id do usuário. Para saber se é a sua vez, ache o seu jogador pelo `nickname`.
7. **409 (conflito): consulte o estado de novo** antes de tentar outra vez.

## Passo 1: o `GameController`

Ele guarda o estado, faz o polling e expõe as ações. É compartilhado com a sala de espera do lobby.

`controllers/game_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/enums/game_phase.dart';
import '../../domain/usecases/answer_puzzle_usecase.dart';
import '../../domain/usecases/buy_trophy_usecase.dart';
import '../../domain/usecases/cancel_game_usecase.dart';
import '../../domain/usecases/get_game_state_usecase.dart';
import '../../domain/usecases/play_card_usecase.dart';
import '../../domain/usecases/ready_for_next_round_usecase.dart';
import '../../domain/usecases/start_game_usecase.dart';

class GameController extends ChangeNotifier {
  GameController({
    required GameState initial,
    required GetGameStateUseCase getState,
    required StartGameUseCase startGame,
    required PlayCardUseCase playCard,
    required AnswerPuzzleUseCase answerPuzzle,
    required BuyTrophyUseCase buyTrophy,
    required ReadyForNextRoundUseCase ready,
    required CancelGameUseCase cancelGame,
  })  : _state = initial,
        _getState = getState,
        _startGame = startGame,
        _playCard = playCard,
        _answerPuzzle = answerPuzzle,
        _buyTrophy = buyTrophy,
        _ready = ready,
        _cancelGame = cancelGame;

  final GetGameStateUseCase _getState;
  final StartGameUseCase _startGame;
  final PlayCardUseCase _playCard;
  final AnswerPuzzleUseCase _answerPuzzle;
  final BuyTrophyUseCase _buyTrophy;
  final ReadyForNextRoundUseCase _ready;
  final CancelGameUseCase _cancelGame;

  GameState _state;
  GameState get state => _state;

  AppException? error;
  bool busy = false;

  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;

  // ---------- polling ----------

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_polling || busy) return;                  // nao empilha requisicoes
    _polling = true;
    try {
      _apply(await _getState(_state.id));
    } on AppException catch (e) {
      error = e;
      _notify();
    } finally {
      _polling = false;
    }
  }

  /// Publica somente estados novos.
  void _apply(GameState next) {
    if (next.stateVersion <= _state.stateVersion) return;
    _state = next;
    error = null;
    if (next.phase == GamePhase.finalizado || next.phase == GamePhase.cancelado) {
      stopPolling();
    }
    _notify();
  }

  // ---------- acoes ----------

  Future<void> start() => _act(() => _startGame(_state.id));
  Future<void> playCard(int handCardId) => _act(() => _playCard(_state.id, handCardId));
  Future<void> answerPuzzle(int challengeId, int index) =>
      _act(() => _answerPuzzle(_state.id, challengeId, index));
  Future<void> buyTrophy() => _act(() => _buyTrophy(_state.id));
  Future<void> ready() => _act(() => _ready(_state.id));
  Future<void> cancel() => _act(() => _cancelGame(_state.id));

  Future<void> _act(Future<GameState> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      _apply(await action());
    } on ConflictException catch (e) {
      error = e;
      await _refresh();                            // regra: 409 -> reconsulta
    } on AppException catch (e) {
      error = e;
    } catch (e) {
      error = UnexpectedException(cause: e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _refresh() async {
    try {
      _apply(await _getState(_state.id));
    } on AppException {/* o polling tenta de novo */}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();                                 // sem isso o Timer continua!
    super.dispose();
  }
}
```

Conceitos importantes:
- **`_polling`** impede que uma requisição lenta faça duas rodarem juntas.
- **`_apply`** ignora estados velhos. A resposta de uma ação e o polling podem chegar fora de ordem; o `stateVersion` resolve.
- **`dispose` cancela o `Timer`.** Esquecer isso é o bug mais comum: o app continua chamando a API depois de sair da tela.
- As ações ficam "sem retorno" na tela: ela só reage ao `state` novo.

## Passo 2: identificar "eu" e "minha vez"

Como o `GameState` não traz o id do usuário, ache-se pelo apelido. Crie um helper (por exemplo no topo do `game_page.dart`):

```dart
GamePlayer? findMe(GameState s, String nickname) {
  for (final p in s.players) {
    if (p.nickname == nickname) return p;
  }
  return null;
}

bool isMyTurn(GameState s, GamePlayer? me) =>
    me != null && s.currentPlayerId == me.id;
```

## Passo 3: a página e o esqueleto

`pages/game_page.dart`:

```dart
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.controller, required this.myNickname, required this.onExit});

  final GameController controller;
  final String myNickname;
  final VoidCallback onExit;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  bool _puzzleOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.startPolling();
    widget.controller.addListener(_maybeShowPuzzle);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_maybeShowPuzzle);
    widget.controller.dispose();
    super.dispose();
  }
  ...
}
```

No `build`, use `ListenableBuilder` e monte a coluna:

```dart
final s = widget.controller.state;
final me = findMe(s, widget.myNickname);
final myTurn = isMyTurn(s, me);

Column(children: [
  _Header(state: s),                               // rodada, direcao, vira
  PlayersBar(players: s.players, currentPlayerId: s.currentPlayerId, myId: me?.id),
  Expanded(child: TablePlays(plays: s.plays)),
  if (widget.controller.error != null) _ErrorBanner(widget.controller.error!),
  _Actions(...),                                   // troféu / pronto / cancelar
  HandView(
    hand: s.hand,
    enabled: myTurn && !widget.controller.busy && s.roundStatus == RoundStatus.emAndamento,
    onPlay: widget.controller.playCard,
  ),
])
```

## Passo 4: cada pedaço da tela

### 4.1 Cabeçalho (rodada, direção, vira)

```dart
Text('Rodada ${s.roundNumber}'),
Icon(s.direction == GameDirection.horario ? Icons.rotate_right : Icons.rotate_left),
if (s.vira != null) CardTile(valor: s.vira!.valor, naipe: s.vira!.naipe),
```

A **vira** define a manilha, mas quem calcula isso é o servidor. O app apenas exibe.

### 4.2 Barra de jogadores (`widgets/players_bar.dart`)

Para cada `GamePlayer`: apelido, `matchCoins`, `trophies`, `handSize` (cartas na mão do adversário). Destaque quem tem `id == currentPlayerId` e marque você.

```dart
Card(
  color: p.id == currentPlayerId ? scheme.primaryContainer : null,
  child: Column(children: [
    Text(p.id == myId ? '${p.nickname} (voce)' : p.nickname),
    Text('🪙 ${p.matchCoins}  🏆 ${p.trophies}  🃏 ${p.handSize}'),
  ]),
)
```

### 4.3 Mesa (`widgets/table_plays.dart`)

Mostra `plays` ordenadas por `order`: quem jogou qual carta.

```dart
final sorted = [...plays]..sort((a, b) => a.order.compareTo(b.order));
Wrap(children: [
  for (final p in sorted)
    Column(children: [
      Text(p.nickname),
      SizedBox(width: 70, height: 100, child: CardTile(valor: p.card.valor, naipe: p.card.naipe)),
      if (p.card.skill != null) Text(p.card.skill!.name),   // .name do enum
    ]),
])
```

### 4.4 Sua mão (`widgets/hand_view.dart`)

```dart
class HandView extends StatelessWidget {
  const HandView({super.key, required this.hand, required this.enabled, required this.onPlay});

  final List<GameCard> hand;
  final bool enabled;
  final void Function(int handCardId) onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in hand)
            SizedBox(
              width: 80,
              child: Opacity(
                opacity: enabled ? 1 : .5,
                child: CardTile(
                  valor: c.valor,
                  naipe: c.naipe,
                  // handCardId (nunca catalogCardId) e o unico id aceito ao jogar
                  onTap: enabled && c.handCardId != null ? () => onPlay(c.handCardId!) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

### 4.5 Puzzle pendente (`widgets/puzzle_dialog.dart`)

Quando `roundStatus == aguardandoPuzzle` e existe `pendingPuzzle`, mostre um diálogo bloqueante. **A resposta é enviada como índice da alternativa**, e o servidor diz se acertou.

```dart
Future<void> showPuzzleDialog(BuildContext context, PendingPuzzle puzzle, GameController c) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SimpleDialog(
      title: Text(puzzle.question),
      children: [
        for (var i = 0; i < puzzle.alternatives.length; i++)
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(context).pop();
              c.answerPuzzle(puzzle.challengeId, i);
            },
            child: Text(puzzle.alternatives[i]),
          ),
      ],
    ),
  );
}
```

E no `_GamePageState`:

```dart
void _maybeShowPuzzle() {
  final s = widget.controller.state;
  if (s.pendingPuzzle != null && s.roundStatus == RoundStatus.aguardandoPuzzle && !_puzzleOpen) {
    _puzzleOpen = true;
    showPuzzleDialog(context, s.pendingPuzzle!, widget.controller)
        .whenComplete(() => _puzzleOpen = false);
  }
}
```

A flag `_puzzleOpen` evita abrir o mesmo diálogo várias vezes a cada `notifyListeners`.

> Cuidado: o puzzle pode ser de **outro** jogador. Confira se `s.currentPlayerId == me.id` antes de abrir o diálogo, senão todos verão a pergunta. Teste isso com dois jogadores.

### 4.6 Ações fora da jogada

```dart
if (s.phase == GamePhase.entreRodadas)
  FilledButton(onPressed: c.busy ? null : c.ready, child: const Text('Proxima rodada')),

OutlinedButton(
  onPressed: c.busy ? null : c.buyTrophy,
  child: Text('Comprar trofeu (${s.settings.trophyPrice} moedas)'),
),

if (me?.host == true)
  TextButton(onPressed: c.cancel, child: const Text('Cancelar partida')),
```

Desabilitar o troféu quando `me.matchCoins < trophyPrice` é **conforto de UI**. Se o usuário ainda assim conseguir chamar, a API responde com erro e a mensagem aparece.

### 4.7 Fim de jogo

Quando `phase == finalizado`, mostre o vencedor (`winnerPlayerId` é um `GamePlayer.id`):

```dart
final winner = s.players.firstWhere((p) => p.id == s.winnerPlayerId);
Text(winner.nickname == widget.myNickname ? 'Voce venceu!' : 'Vencedor: ${winner.nickname}');
FilledButton(onPressed: widget.onExit, child: const Text('Voltar ao menu'));
```

`cancelado` também encerra: mostre "Partida cancelada" e um botão para sair.

## Passo 5: testar com dois jogadores

1. Crie e inicie a partida (tutorial do lobby).
2. Só o jogador da vez consegue tocar nas cartas; o outro vê a mão apagada.
3. Toque em uma carta: ela some da sua mão e aparece na mesa dos dois em ~1 segundo.
4. Jogue uma carta com skill de puzzle: só o jogador certo vê o diálogo.
5. Faça uma jogada inválida ou sem sua vez (use dois dispositivos): a mensagem da API aparece e o estado é recarregado se for 409.
6. Feche a tela no meio da partida e confirme (log/depurador) que o polling parou.

## Erros mais comuns

| Sintoma | Causa provável |
|---|---|
| A tela pisca ou fica estranha | Estado antigo sobrescrevendo o novo: falta o `stateVersion` no `_apply` |
| O app continua chamando a API ao sair | `dispose` sem `stopPolling` |
| "Não é sua vez" com o botão liberado | Comparou `currentPlayerId` com `session.user.id` em vez de `GamePlayer.id` |
| 400 ao jogar carta | Enviou `catalogCardId` em vez de `handCardId` |
| Diálogo de puzzle aparece duas vezes | Falta a flag `_puzzleOpen` |
| Vencedor errado na tela | Comparou `winnerPlayerId` com o id do usuário |

## Exercícios

1. Adicione um `SnackBar` que mostra a mensagem de `controller.error` e limpa o erro.
2. Destaque na mesa a carta vencedora quando a rodada terminar (use apenas o que a API devolve, sem calcular a força das cartas).
3. Anime a entrada da carta jogada com `AnimatedSwitcher`.
4. Mostre o histórico do ranking depois do fim da partida chamando o ranking.
5. Escreva um teste do `GameController` com casos de uso falsos: dois estados com a mesma versão devem notificar apenas uma vez.
