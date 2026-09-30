# Interfaces de domínio Dart alinhadas à API Truno Crazzy

Este documento descreve o que deve existir na camada de domínio do aplicativo Flutter para consumir integralmente o contrato OpenAPI atual da API. Ele não define implementação HTTP, JSON, armazenamento local ou gerenciamento de estado de tela.

## 1. Regras de modelagem comuns

- Todos os identificadores enviados pela API como `int64` devem ser representados por `int` no Dart, nunca por `String`.
- O token retornado no login é enviado no header `X-Player-Token` em todas as operações de partida.
- O token deve ser anexado pela implementação da camada de dados. As interfaces de domínio não precisam receber o token em cada método.
- Os nomes JSON em maiúsculas devem ser convertidos para enums Dart. A conversão entre enum e texto pertence à camada de dados.
- O domínio não deve conhecer `Map<String, dynamic>`, `Response`, códigos HTTP, headers ou bibliotecas HTTP.
- Todas as operações remotas devem ser assíncronas.
- Falhas `400`, `401`, `403`, `404` e `409` devem virar exceções/falhas tipadas do app, preservando a mensagem devolvida pela API.
- `stateVersion` deve ser guardado como `int`. A apresentação pode ignorar um estado cuja versão seja igual à última versão processada.
- A API é a fonte de verdade. O app não deve calcular vencedor, manilha, moedas, skills, turnos ou compra de troféu localmente.

## 2. Enums obrigatórios

### `GamePhase`

Representa `phase` em `GameStateResponse`:

- `aguardandoJogadores` ↔ `AGUARDANDO_JOGADORES`
- `emAndamento` ↔ `EM_ANDAMENTO`
- `entreRodadas` ↔ `ENTRE_RODADAS`
- `finalizado` ↔ `FINALIZADO`
- `cancelado` ↔ `CANCELADO`

### `RoundStatus`

Representa `roundStatus`:

- `emAndamento` ↔ `EM_ANDAMENTO`
- `aguardandoPuzzle` ↔ `AGUARDANDO_PUZZLE`
- `finalizado` ↔ `FINALIZADO`

### `GameDirection`

- `horario` ↔ `HORARIO`
- `antiHorario` ↔ `ANTI_HORARIO`

### `CardValue`

- `as` ↔ `AS`
- `dois` ↔ `DOIS`
- `tres` ↔ `TRES`
- `quatro` ↔ `QUATRO`
- `cinco` ↔ `CINCO`
- `seis` ↔ `SEIS`
- `sete` ↔ `SETE`
- `dama` ↔ `DAMA`
- `valete` ↔ `VALETE`
- `rei` ↔ `REI`

Para exibição e cálculo visual da sequência, a ordem do jogo é: `4, 5, 6, 7, Q, J, K, A, 2, 3`.

### `CardSuit`

- `ouros` ↔ `OUROS`
- `espadas` ↔ `ESPADAS`
- `copas` ↔ `COPAS`
- `paus` ↔ `PAUS`

### `SkillType`

- `block` ↔ `BLOCK`
- `theft` ↔ `THEFT`
- `inverts` ↔ `INVERTS`
- `buy` ↔ `BUY`
- `burn` ↔ `BURN`
- `surprise` ↔ `SURPRISE`
- `puzzle` ↔ `PUZZLE`
- `changeOfHands` ↔ `CHANGEOFHANDS`
- `bomb` ↔ `BOMB`
- `shield` ↔ `SHIELD`

## 3. Entidades e value objects

### Autenticação

#### `PlayerUser`

Representa `UserResponse`:

| Campo | Tipo | Obrigatório |
|---|---|---|
| `id` | `int` | sim |
| `nickname` | `String` | sim |
| `rankingPoints` | `int` | sim |

Não deve possuir `email`, `name`, `avatarUrl` ou saldo de moedas. As moedas pertencem ao jogador dentro de uma partida.

#### `AuthSession`

Representa `AuthResponse`:

| Campo | Tipo | Obrigatório |
|---|---|---|
| `token` | `String` | sim |
| `user` | `PlayerUser` | sim |

A API não trabalha com `refreshToken`. Esse campo deve ser removido do domínio atual.

#### `LoginCredentials`

Entrada do login:

| Campo | Regra |
|---|---|
| `nickname` | não vazio; máximo de 30 caracteres |
| `code` | de 4 a 30 caracteres |

### Partida

#### `CreateGameInput`

Representa `CreateGameRequest`:

| Campo | Tipo | Regra |
|---|---|---|
| `name` | `String` | não vazio; máximo de 60 caracteres |
| `maxPlayers` | `int` | entre 2 e 6 |
| `initialCards` | `int` | entre 1 e 10 |
| `roundReward` | `int` | zero ou maior |
| `emptyHandReward` | `int` | zero ou maior |
| `trophyPrice` | `int` | maior que zero pelas regras atuais |

#### `GameSettings`

Representa `Settings` devolvido no estado:

- `maxPlayers: int`
- `initialCards: int`
- `roundReward: int`
- `emptyHandReward: int`
- `trophyPrice: int`

#### `GamePlayer`

Representa `PlayerView`:

- `id: int` — identificador do jogador dentro da partida, usado por `currentPlayerId` e `winnerPlayerId`.
- `nickname: String`
- `position: int`
- `matchCoins: int`
- `trophies: int`
- `handSize: int`
- `ready: bool`
- `host: bool`

Não confundir `GamePlayer.id` com `PlayerUser.id`. O estado da partida usa o ID de `GamePlayer` para turno e vencedor.

#### `GameCard`

Representa `CardView`:

- `handCardId: int?` — existe para cartas da própria mão; pode ser nulo na vira e nas jogadas públicas.
- `catalogCardId: int`
- `value: CardValue`
- `suit: CardSuit`
- `skill: SkillType?` — nulo para cartas comuns.

Somente `handCardId` pode ser enviado ao endpoint de jogada. Nunca enviar `catalogCardId` para jogar uma carta.

#### `GamePlay`

Representa `PlayView`:

- `playerId: int`
- `nickname: String`
- `card: GameCard`
- `order: int`

#### `PendingPuzzle`

Representa `PuzzleView` dentro da partida:

- `challengeId: int`
- `question: String`
- `alternatives: List<String>`

Não deve existir resposta correta nessa entidade.

#### `GameState`

É o agregado principal do jogo e representa `GameStateResponse`:

| Campo | Tipo | Pode ser nulo |
|---|---|---|
| `id` | `int` | não |
| `code` | `String` | não |
| `name` | `String` | não |
| `phase` | `GamePhase` | não |
| `stateVersion` | `int` | não |
| `settings` | `GameSettings` | não |
| `direction` | `GameDirection` | não |
| `roundNumber` | `int` | não |
| `roundStatus` | `RoundStatus?` | sim, antes da primeira rodada |
| `vira` | `GameCard?` | sim, no lobby ou após encerramento conforme resposta |
| `currentPlayerId` | `int?` | sim, fora de uma rodada ativa |
| `players` | `List<GamePlayer>` | não |
| `plays` | `List<GamePlay>` | não |
| `hand` | `List<GameCard>` | não |
| `pendingPuzzle` | `PendingPuzzle?` | sim |
| `winnerPlayerId` | `int?` | sim, até a partida terminar |

A lista `hand` contém exclusivamente a mão do usuário autenticado. Para os adversários, usar somente `GamePlayer.handSize`.

### Catálogos públicos

#### `CatalogCard`

Representa `CardResponse`:

- `id: int`
- `value: CardValue`
- `suit: CardSuit`

É diferente de `GameCard`: uma carta de catálogo não possui `handCardId` nem skill embutida.

#### `SkillDefinition`

Representa `SkillResponse`:

- `id: int`
- `name: String`
- `description: String`
- `type: SkillType`
- `suit: CardSuit`
- `value: CardValue`

#### `PuzzleDefinition`

Representa `PuzzleResponse`:

- `id: int`
- `question: String`
- `alternatives: List<String>`

Não deve possuir `alternativaCorreta`. A resposta é validada exclusivamente pela API.

#### `RankingEntry`

Representa `RankingResponse`:

- `id: int`
- `nickname: String`
- `rankingPoints: int`

Mesmo tendo os mesmos campos básicos de `PlayerUser`, deve ser uma entidade própria porque representa uma posição/listagem de ranking, não a sessão autenticada.

## 4. Interfaces de repositório

### `AuthRepository`

Responsabilidade: autenticação remota.

| Operação | Entrada | Retorno |
|---|---|---|
| `login` | `LoginCredentials` | `Future<AuthSession>` |

Mapeia `POST /auth/sessions`.

### `SessionRepository`

Responsabilidade: guardar a sessão localmente para que o app consiga reutilizar o token.

| Operação | Retorno/entrada |
|---|---|
| salvar sessão | recebe `AuthSession` |
| obter sessão atual | `Future<AuthSession?>` |
| limpar sessão | sem retorno relevante |

Esse repositório é local; não existe endpoint de logout na API. Limpar a sessão remove apenas os dados locais.

### `GameRepository`

Responsabilidade: todas as operações de partida.

| Operação de domínio | Endpoint | Entrada | Retorno |
|---|---|---|---|
| criar partida | `POST /games` | `CreateGameInput` | `Future<GameState>` |
| acessar partida | `POST /games/access` | código de 6 caracteres | `Future<GameState>` |
| iniciar partida | `POST /games/{id}/start` | `gameId` | `Future<GameState>` |
| obter estado | `GET /games/{id}/state` | `gameId` | `Future<GameState>` |
| jogar carta | `POST /games/{id}/plays` | `gameId`, `handCardId` | `Future<GameState>` |
| responder puzzle | `POST /games/{id}/puzzle-answers` | `gameId`, `challengeId`, `alternativeIndex` | `Future<GameState>` |
| comprar troféu | `POST /games/{id}/trophies` | `gameId` | `Future<GameState>` |
| confirmar próxima rodada | `POST /games/{id}/ready` | `gameId` | `Future<GameState>` |
| cancelar partida | `POST /games/{id}/cancel` | `gameId` | `Future<GameState>` |

Todas as mutações retornam o estado agregado atualizado. A tela deve substituir seu estado local pelo retorno da API.

### `RankingRepository`

| Operação | Endpoint | Retorno |
|---|---|---|
| listar ranking | `GET /users/ranking` | `Future<List<RankingEntry>>` |

### `CardCatalogRepository`

| Operação | Endpoint | Retorno |
|---|---|---|
| listar cartas | `GET /cards` | `Future<List<CatalogCard>>` |
| buscar carta | `GET /cards/{id}` | `Future<CatalogCard>` |

### `SkillCatalogRepository`

| Operação | Endpoint | Retorno |
|---|---|---|
| listar skills | `GET /skills` | `Future<List<SkillDefinition>>` |

### `PuzzleCatalogRepository`

| Operação | Endpoint | Retorno |
|---|---|---|
| listar puzzles públicos | `GET /puzzles` | `Future<List<PuzzleDefinition>>` |
| buscar puzzle público | `GET /puzzles/{id}` | `Future<PuzzleDefinition>` |

Esse repositório não responde desafios da partida. A resposta pertence ao `GameRepository`, pois exige `gameId` e `challengeId`.

## 5. Casos de uso necessários

Cada caso de uso deve ser pequeno e delegar ao repositório correspondente. As regras decisivas continuam no backend.

### Autenticação

- `LoginUseCase`
- `GetCurrentSessionUseCase`
- `ClearSessionUseCase`

### Lobby e partida

- `CreateGameUseCase`
- `AccessGameUseCase`
- `StartGameUseCase`
- `GetGameStateUseCase`
- `PlayCardUseCase`
- `AnswerPuzzleUseCase`
- `BuyTrophyUseCase`
- `ReadyForNextRoundUseCase`
- `CancelGameUseCase`

### Ranking e catálogos

- `GetRankingUseCase`
- `ListCardsUseCase`
- `GetCardUseCase`
- `ListSkillsUseCase`
- `ListPuzzlesUseCase`
- `GetPuzzleUseCase`

O polling de aproximadamente um segundo é uma responsabilidade de coordenação da apresentação/application layer. Ele deve chamar `GetGameStateUseCase`, comparar `stateVersion` e publicar somente estados novos. Não é necessário criar um endpoint ou regra de domínio para polling.

## 6. O que fazer com o domínio Dart atual

### Auth

| Arquivo atual | Ação necessária |
|---|---|
| `auth_session.dart` | trocar `accessToken` opcional por `token` obrigatório; remover `refreshToken`; incluir `PlayerUser`; retirar a classe `AppException`, pois ela já pertence ao core |
| `user.dart` | substituir `String id`, `name`, `email` e `avatarUrl` por `int id`, `nickname` e `rankingPoints` |
| `auth.repository.dart` | preencher com a interface `AuthRepository`; atualmente está vazio |
| `get_current_user_usecase.dart` | revisar para trabalhar com sessão/usuário atual; atualmente está vazio |

### Catálogo

| Arquivo atual | Ação necessária |
|---|---|
| `carta_truco.dart` | manter os conceitos de valor e naipe, corrigir os símbolos corrompidos e adicionar o ID do catálogo em uma entidade apropriada |
| `catalogo_repository.dart` | mover a abstração para `domain/repositories`; hoje é uma classe concreta acoplada ao serviço local |
| `baralho_truco.dart` e `baralho_truco_service.dart` | deixar apenas para demonstração offline ou remover; o baralho oficial vem de `GET /cards` |

### Lobby/jogo

| Arquivo atual | Ação necessária |
|---|---|
| `game.dart` | substituir pelo agregado completo `GameState`; `maxPlayers` deve ser `int`, não `String` |
| `round.dart` | não manter uma rodada independente com lista de nomes; incorporar status, número, vira e jogadas no `GameState` |
| `GameRepository.dart` | substituir todos os métodos pelo contrato completo descrito acima; criação não recebe `lobbyId` e retorna `GameState` |
| `RoundRepository.dart` | remover; a API não possui endpoints de criação, busca ou finalização manual de rodada |
| `StartGameUseCase.dart` | simplificar para chamar `GameRepository.startGame`; não consultar `RoundRepository` antes de iniciar |

### Puzzle

| Arquivo atual | Ação necessária |
|---|---|
| `puzzle.dart` | adicionar `question`; trocar ID para `int`; remover `alternativaCorreta` |
| `puzzleRepository.dart` | remover busca aleatória, categoria, dificuldade e `PostResponsePuzzle`; esses endpoints não existem |
| `responderUseCase.dart` | substituir por `AnswerPuzzleUseCase`, usando `gameId`, `challengeId` e `alternativeIndex` e retornando `GameState` |
| `sortearUseCase.dart` | remover; o backend escolhe o puzzle ao executar a skill |
| `pegarUseCase.dart` | revisar ou remover; atualmente repete a implementação de resposta e não representa um endpoint da API |

## 7. Organização de pastas recomendada

Esta estrutura mantém os nomes próximos das features atuais sem misturar domínio com HTTP:

```text
lib/
  core/
    error/
      app_exception.dart
  features/
    auth/
      domain/
        entities/
          auth_session.dart
          player_user.dart
          login_credentials.dart
        repositories/
          auth_repository.dart
          session_repository.dart
        usecases/
          login_usecase.dart
          get_current_session_usecase.dart
          clear_session_usecase.dart
    game/
      domain/
        entities/
          game_state.dart
          game_settings.dart
          game_player.dart
          game_card.dart
          game_play.dart
          pending_puzzle.dart
        enums/
          game_phase.dart
          round_status.dart
          game_direction.dart
          card_value.dart
          card_suit.dart
          skill_type.dart
        inputs/
          create_game_input.dart
        repositories/
          game_repository.dart
        usecases/
          create_game_usecase.dart
          access_game_usecase.dart
          start_game_usecase.dart
          get_game_state_usecase.dart
          play_card_usecase.dart
          answer_puzzle_usecase.dart
          buy_trophy_usecase.dart
          ready_for_next_round_usecase.dart
          cancel_game_usecase.dart
    catalog/
      domain/
        entities/
          catalog_card.dart
          skill_definition.dart
          puzzle_definition.dart
        repositories/
          card_catalog_repository.dart
          skill_catalog_repository.dart
          puzzle_catalog_repository.dart
        usecases/
          list_cards_usecase.dart
          get_card_usecase.dart
          list_skills_usecase.dart
          list_puzzles_usecase.dart
          get_puzzle_usecase.dart
    ranking/
      domain/
        entities/
          ranking_entry.dart
        repositories/
          ranking_repository.dart
        usecases/
          get_ranking_usecase.dart
```

## 8. Ordem sugerida de implementação

1. Criar enums e entidades sem dependência de HTTP.
2. Corrigir `PlayerUser` e `AuthSession`.
3. Definir `AuthRepository` e `SessionRepository`.
4. Criar o agregado `GameState` e suas entidades filhas.
5. Substituir `GameRepository` e remover `RoundRepository`.
6. Corrigir o domínio de puzzle para nunca receber a alternativa correta.
7. Criar interfaces de ranking e catálogos.
8. Criar os casos de uso finos.
9. Somente depois implementar DTOs, mappers, cliente HTTP e armazenamento do token na camada `data`.
10. Por último, adaptar estados e telas para usar `GameState` e `stateVersion`.

## 9. Checklist de alinhamento completo

- [ ] Nenhum ID da API permanece como `String`.
- [ ] O usuário não possui e-mail nem saldo persistente no domínio.
- [ ] A sessão possui apenas `token` e usuário autenticado.
- [ ] O token é enviado automaticamente como `X-Player-Token`.
- [ ] O app representa todas as cinco fases de jogo.
- [ ] O app representa o estado intermediário `AGUARDANDO_PUZZLE`.
- [ ] O app representa direção, configurações, vira, turno, jogadas e vencedor.
- [ ] A própria mão usa `handCardId`; adversários mostram somente `handSize`.
- [ ] Puzzle público ou pendente nunca contém a resposta correta.
- [ ] Não existe criação/finalização manual de rodada no app.
- [ ] Não existe criação/remoção de cartas, skills ou puzzles no app.
- [ ] Todas as ações de partida substituem o estado local pelo `GameState` retornado.
- [ ] O polling ignora versões já processadas.
- [ ] Respostas `401` limpam ou invalidam a sessão local.
- [ ] Respostas `409` provocam uma nova consulta do estado antes de tentar novamente.
- [ ] Todas as rotas do OpenAPI possuem um método de repositório e um caso de uso correspondente.
