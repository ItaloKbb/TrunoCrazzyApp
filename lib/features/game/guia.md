# Guia da tela de Game

## O que já existe

O domínio e a camada de dados do jogo estão prontos: `GameState`, `GamePlayer`, `GameCard`, `PendingPuzzle`, `GameRepositoryImpl` e os casos de uso em `lib/features/game/domain/usecases/`. Falta a apresentação. A API é a fonte de verdade para turno, cartas, moedas, troféus, skills e vencedor. Cada ação retorna um `GameState` atualizado.

Crie `presentation/controllers/game_controller.dart`, `presentation/pages/game_page.dart` e widgets menores para jogadores, mesa, mão e puzzle. `presentation/index.md` tem um exemplo mais extenso de widgets. Este guia foca na ordem de implementação e nas regras de integração.

## 1. Monte o controller e o polling

Injete no `GameController` o estado devolvido ao criar/entrar e estes casos de uso: `GetGameStateUseCase`, `StartGameUseCase`, `PlayCardUseCase`, `AnswerPuzzleUseCase`, `BuyTrophyUseCase`, `ReadyForNextRoundUseCase` e `CancelGameUseCase`. Todos usam **o mesmo** `GameRepositoryImpl(_api)` montado fora da tela.

O controller expõe `GameState state`, `bool busy`, `AppException? error`, `startPolling()` e `stopPolling()`. Inicie o polling uma vez ao entrar na rota de partida; pare no `dispose` e quando `phase` ficar `finalizado` ou `cancelado`. Use um `Timer.periodic` de cerca de um segundo, com uma flag para impedir consultas sobrepostas. Uma consulta que falhou não deve substituir o último estado válido.

```dart
void apply(GameState next) {
  if (next.stateVersion <= state.stateVersion) return;
  state = next;
  error = null;
  if (next.phase == GamePhase.finalizado ||
      next.phase == GamePhase.cancelado) {
    stopPolling();
  }
  notifyListeners();
}
```

Tanto o retorno do polling quanto o de cada ação passam por `apply`. Isso evita que uma resposta antiga sobrescreva um estado mais novo. Não chame `getGameState` dentro de `build`. O controller pertence à **rota inteira** de partida: a sala de espera e a tela de jogo recebem o mesmo objeto; só a rota chama `dispose`.

## 2. Desenhe a partida a partir de `GameState`

Monte a tela em seções pequenas:

| Seção | Campos do estado |
|---|---|
| Cabeçalho | `name`, `code`, `roundNumber`, `direction`, `vira` |
| Jogadores | `players`: `nickname`, `matchCoins`, `trophies`, `handSize`, `ready`, `host` |
| Mesa | `plays` na ordem `order`; cada item tem jogador e carta |
| Minha mão | `hand`; só nela existe `handCardId` para jogar |
| Ações | `phase`, `roundStatus`, `currentPlayerId`, `pendingPuzzle`, `settings.trophyPrice` |
| Resultado | `winnerPlayerId` comparado a IDs em `players` |

Para destacar a sua vez, ache seu `GamePlayer` pelo apelido da sessão e compare `state.currentPlayerId == me.id`. O `PlayerUser.id` não é o identificador de jogador da partida. Se nenhum jogador corresponder, desabilite ações e mostre um estado de erro recuperável.

Use o catálogo apenas para elementos visuais compartilhados; `CatalogCard.id`/`GameCard.catalogCardId` não serve para jogar. O botão de carta só fica ativo quando `phase == emAndamento`, `roundStatus == RoundStatus.emAndamento`, é a sua vez, há `handCardId` e `busy == false`.

```dart
final cardId = card.handCardId;
if (cardId != null) {
  await controller.playCard(cardId); // POST /games/{id}/plays
}
```

## 3. Implemente cada ação pela API

| Ação da tela | Caso de uso | O que enviar |
|---|---|---|
| Jogar carta | `PlayCardUseCase` | `gameId` e `handCardId` |
| Responder desafio | `AnswerPuzzleUseCase` | `gameId`, `challengeId`, índice da alternativa (base zero) |
| Comprar troféu | `BuyTrophyUseCase` | `gameId` |
| Confirmar próxima rodada | `ReadyForNextRoundUseCase` | `gameId` |
| Cancelar partida | `CancelGameUseCase` | `gameId` |

Durante cada ação, marque `busy`, desabilite botões e mostre progresso; no sucesso, aplique o `GameState` retornado. Se vier `ConflictException` (`409`), preserve a mensagem e consulte o estado novamente antes de permitir outra tentativa. Para outras `AppException`, mostre `error.message`. O `401` já dispara `onUnauthorized` em `ApiClient`.

Quando `roundStatus == RoundStatus.aguardandoPuzzle` e `pendingPuzzle != null`, mostre a pergunta e `alternatives` somente ao jogador da vez. Use `pendingPuzzle.challengeId` e o índice selecionado; a resposta certa não vem no cliente. Proteja o diálogo contra abertura repetida por `notifyListeners` e cheque `mounted` após ações assíncronas.

Na fase `entreRodadas`, mostre **Pronto para próxima rodada** e o estado `ready` dos jogadores. Em `finalizado`, procure o jogador de `winnerPlayerId` em `players`; se não encontrar, mostre um resultado genérico em vez de lançar erro. Em `cancelado`, informe o cancelamento e ofereça retorno ao menu. Não calcule vencedor/manilha no app.

## 4. Encaixe na navegação

O Lobby abre uma rota de partida com o `GameState` inicial. Essa rota mantém o `GameController` enquanto alterna sala de espera e jogo. A dock fica na área principal do app, fora da partida; voltar à Home fecha a rota e libera o controller. Veja [Lobby](../lobby/guia.md) e [dock](../../../guia_dock.md).

## 5. Verifique os casos decisivos

1. Com dois usuários, a ação de um aparece para o outro após o polling; apenas o jogador da vez joga.
2. Uma carta jogada usa `handCardId` e desaparece da própria `hand` após o estado retornado.
3. Um `409` mostra a mensagem e atualiza o estado; uma resposta antiga nunca regride `stateVersion`.
4. Um puzzle aparece uma vez, só para quem deve responder, e envia o índice correto.
5. Ao encerrar/cancelar ou sair da rota, não restam requisições periódicas.
