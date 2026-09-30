# Guia do Lobby

## O fluxo que você vai criar

O Lobby permite criar uma partida, entrar com um código e aguardar jogadores. A API entrega um `GameState` após **criar** (`POST /games`) ou **entrar** (`POST /games/access`). Na sala de espera, `GET /games/{id}/state` atualiza a lista; o host pode iniciar com `POST /games/{id}/start` ou cancelar com `POST /games/{id}/cancel`.

O projeto já possui `GameRepositoryImpl`, `CreateGameInput` e os casos de uso `CreateGameUseCase`, `AccessGameUseCase`, `GetGameStateUseCase`, `StartGameUseCase` e `CancelGameUseCase`. Não há endpoint para listar salas nem sair individualmente de uma partida; não invente esses fluxos.

Crie em `lib/features/lobby/presentation/`:

```text
controllers/lobby_controller.dart
pages/lobby_page.dart
pages/create_game_page.dart
pages/waiting_room_page.dart
```

O tutorial em `presentation/index.md` traz widgets maiores para cada página. O roteiro abaixo mostra como conectá-los ao contêiner de navegação e ao controle de estado da partida.

## 1. Monte as dependências uma vez

No mesmo lugar em que `main.dart` cria `_api`, faça:

```dart
final gameRepository = GameRepositoryImpl(_api);
final createGame = CreateGameUseCase(gameRepository);
final accessGame = AccessGameUseCase(gameRepository);
final getGameState = GetGameStateUseCase(gameRepository);
final startGame = StartGameUseCase(gameRepository);
final cancelGame = CancelGameUseCase(gameRepository);
```

Passe os casos de uso ou um objeto de dependências para a área autenticada. A página não deve criar `ApiClient`. O token de sessão será anexado pelo cliente HTTP. Declare os campos no `State`/objeto de dependências conforme o tempo de vida escolhido; o trecho ilustra a montagem, não variáveis locais soltas que seriam recriadas em `build`.

## 2. Faça a entrada do Lobby

Em `LobbyController extends ChangeNotifier`, injete `CreateGameUseCase` e `AccessGameUseCase`. Guarde `loading` e `AppException? error`. O método `create(CreateGameInput input)` e o método `access(String code)` devem retornar `Future<GameState?>`: em sucesso entregam o estado; em erro guardam a mensagem e retornam `null`. Bloqueie o segundo toque enquanto `loading` for `true`.

Na `LobbyPage`, coloque dois caminhos:

- **Criar partida** abre `CreateGamePage`. O formulário produz `CreateGameInput` e chama `input.isValid` antes de enviar.
- **Entrar** recebe um código de seis caracteres; use `trim().toUpperCase()` para feedback da interface. O próprio `GameRepositoryImpl.accessGame` normaliza o código antes da API.

Mostre `controller.error?.message` perto da ação e desabilite botões durante a chamada. Depois de `await`, cheque `mounted` antes de navegar. Na criação, os campos de `CreateGameInput` são: `name` (até 60 caracteres), `maxPlayers` (2 a 6), `initialCards` (1 a 10), `roundReward` e `emptyHandReward` (não negativos) e `trophyPrice` (positivo). `int.tryParse` permite mostrar erro de campo sem lançar exceção.

```dart
final input = CreateGameInput(
  name: nameController.text.trim(),
  maxPlayers: selectedPlayers,
  initialCards: selectedCards,
  roundReward: int.tryParse(roundRewardController.text) ?? -1,
  emptyHandReward: int.tryParse(emptyRewardController.text) ?? -1,
  trophyPrice: int.tryParse(trophyPriceController.text) ?? 0,
);
if (!input.isValid) {
  // Mostre quais campos precisam ser corrigidos.
  return;
}
final state = await lobbyController.create(input);
if (state != null && mounted) onGameCreated(state);
```

O servidor continua validando os dados. Se retornar `400`, apresente a mensagem de `AppException` ao jogador.

## 3. Crie uma única área de partida

Quando criar/entrar retornar `GameState`, abra **uma rota** que seja dona de um `GameController` e alterne entre `WaitingRoomPage` e `GamePage` conforme `state.phase`. Assim o polling e o controller continuam vivos na troca de sala de espera para jogo, e são liberados ao fechar a rota. Veja [guia do Game](../game/guia.md).

```dart
Widget contentFor(GameState state) => switch (state.phase) {
  GamePhase.aguardandoJogadores => WaitingRoomPage(controller: controller),
  _ => GamePage(controller: controller),
};
```

Os construtores acima são ilustrativos: passe também o apelido e callbacks que você definir. Se escolher páginas com `Scaffold` próprio, não aninhe `Scaffold`s. Uma alternativa é fazer a rota ter o `Scaffold` e as páginas fornecerem apenas seus corpos.

## 4. Faça a sala de espera reagir ao servidor

Mostre `state.code` com botão de copiar, `state.name`, quantidade `state.players.length / state.settings.maxPlayers` e a lista de `GamePlayer` com apelido e indicação de host. O polling de aproximadamente um segundo usa `GetGameStateUseCase` e só publica um estado com `stateVersion` maior. A `WaitingRoomPage` escuta o controller com `ListenableBuilder`; ela não faz requisição em `build`.

Para descobrir se o usuário é host, encontre o jogador pelo `session.user.nickname` na lista e leia `player.host`. **Não** compare `GamePlayer.id` com `PlayerUser.id`: são IDs diferentes. Mostre **Iniciar** apenas ao host; pode desabilitar se houver menos de dois jogadores para dar feedback imediato. A API faz a validação definitiva. Após `startGame`, aplique o `GameState` retornado e deixe a rota mostrar `GamePage` quando `phase == GamePhase.emAndamento`.

Mostre **Cancelar partida** somente ao host e, se a API permitir a ação, aplique o estado `cancelado` e ofereça retorno à Home. Para um convidado, ofereça **Voltar à Home**, explicando que isso apenas fecha a tela local; não existe endpoint de saída individual no contrato atual.

Se a API devolver `409`, mostre a mensagem e consulte `GET /games/{id}/state` antes da próxima ação. Em `401`, o `ApiClient` encerra a sessão pelo callback definido em `main.dart`.

## 5. Verifique com dois usuários

1. Usuário A cria a partida e vê o código e a própria linha como host.
2. Usuário B entra pelo código; A deve vê-lo na sala após a próxima consulta de estado.
3. B não deve ver **Iniciar**; A inicia com pelo menos dois jogadores.
4. Os dois devem ir para a mesma partida, sem polling duplicado nem perda do controller.
5. Ao fechar a rota, confirme que o `Timer` de polling foi cancelado.

Continue no [guia do Game](../game/guia.md) e veja a [dock](../../../guia_dock.md) para abrir o Lobby a partir do app.
