# Guia do Ranking

## Objetivo e contrato

Esta tela mostra a lista devolvida por `GET /users/ranking`, com posição, apelido e pontos, e permite atualizar manualmente. O caminho completo já existe até o caso de uso:

`RankingPage` → `RankingController` → `GetRankingUseCase` → `RankingRepositoryImpl` → `ApiClient` → API.

`RankingEntry` tem `id`, `nickname` e `rankingPoints`. `GetRankingUseCase` e `RankingRepositoryImpl` já existem. Crie apenas a apresentação em `lib/features/ranking/presentation/`. A versão longa do exemplo está em `presentation/index.md`.

## 1. Crie o estado da tela

Use `ViewState<List<RankingEntry>>` de `lib/core/ui/state/view_State.dart`. Ele representa `idle`, `loading`, `success` e `failure`. O estado mantém os dados anteriores durante nova atualização: isso permite mostrar a lista enquanto o usuário puxa para atualizar.

Crie `presentation/controllers/ranking_controller.dart`:

```dart
class RankingController extends ChangeNotifier {
  RankingController(this._getRanking);

  final GetRankingUseCase _getRanking;
  final ViewState<List<RankingEntry>> state = ViewState<List<RankingEntry>>();

  Future<void> load() async {
    if (state.isLoading) return;
    state.setLoading();
    notifyListeners();
    try {
      state.setSuccess(await _getRanking());
    } on AppException catch (error) {
      state.setFailure(error);
    } catch (error) {
      state.setFailure(UnexpectedException(cause: error));
    }
    notifyListeners();
  }
}
```

Adicione os imports de `foundation.dart`, `view_State.dart`, `app_exception.dart`, `ranking_entry.dart` e `get_ranking_usecase.dart` pelos caminhos relativos a esse arquivo. O controller não conhece widgets nem URLs.

## 2. Monte a página

Crie `presentation/pages/ranking_page.dart` com `RankingController controller` e `int currentUserId`. Inicie `controller.load()` em `initState`, escute com `ListenableBuilder` e libere o controller em `dispose` **se a página for sua dona**. Se o contêiner da dock criar e reter o controller, faça o `dispose` no contêiner; nunca nos dois lugares.

| Estado | O que mostrar |
|---|---|
| Primeira carga | `CircularProgressIndicator` centralizado |
| Falha sem dados | Mensagem de `state.error?.message` e botão **Tentar novamente** |
| Lista vazia | Texto "Ainda não há jogadores no ranking" e opção de atualizar |
| Lista carregada | `ListView.builder` com posição `index + 1`, apelido e pontos |
| Atualização com dados antigos | Lista permanece visível; indique progresso e, se falhar, mostre a mensagem sem apagar a lista |

Use `RefreshIndicator(onRefresh: controller.load, child: ListView.builder(physics: const AlwaysScrollableScrollPhysics(), ...))` para permitir atualizar mesmo com poucas entradas. Compare `entry.id == currentUserId` para destacar o jogador. Essa comparação é entre IDs de **usuário**; `GamePlayer.id` pertence apenas à partida e não serve aqui. A ordem exibida deve ser a ordem devolvida pela API; não invente regras de desempate no cliente.

## 3. Conecte no app

No contêiner autenticado, crie o caso de uso com o **mesmo** `_api` configurado no `main.dart`:

```dart
final getRanking = GetRankingUseCase(RankingRepositoryImpl(_api));
final controller = RankingController(getRanking);
// RankingPage(controller: controller, currentUserId: session.user.id)
```

O `ApiClient` já trata falhas HTTP e `401`: apresenta a mensagem da API via `AppException` e chama `onUnauthorized` para limpar a sessão. A tela não deve duplicar token nem fazer `http.get`.

## 4. Verifique

1. Abra Ranking após login: confirme posição, apelido e pontos com a resposta de `GET /users/ranking`.
2. Puxe para atualizar: deve ocorrer uma nova consulta, sem chamadas repetidas a cada `build`.
3. Simule falha de rede: veja a mensagem e o botão de tentar novamente; numa falha de atualização, a lista anterior continua visível.
4. Confirme o destaque pelo `session.user.id`, mesmo que o jogador mude de posição.

Veja também [Home](../home/guia.md), [Profile](../profile/guia.md) e [dock](../../../guia_dock.md).
