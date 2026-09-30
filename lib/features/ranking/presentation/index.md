# Tutorial: criando a tela de Ranking

**Objetivo:** listar os jogadores ordenados por pontos (`GET /users/ranking`), destacando o usuário logado, com carregamento, erro e "puxar para atualizar".

**Pré-requisitos (já existem):** `RankingEntry`, `RankingRepository`, `GetRankingUseCase`, `RankingRepositoryImpl` e o `ViewState<T>` em `lib/core/ui/state/view_State.dart`. Você só cria a **presentation**.

**Arquivos que você vai criar:**

```text
lib/features/ranking/presentation/
  controllers/ranking_controller.dart
  pages/ranking_page.dart
```

O estado usa o `ViewState<List<RankingEntry>>` genérico do core, então não precisa criar um `RankingState`.

---

## Passo 1: conhecer o `ViewState<T>`

```dart
final state = ViewState<List<RankingEntry>>();
state.setLoading();          // isLoading == true
state.setSuccess(lista);     // isSuccess == true, state.data == lista
state.setFailure(erro);      // isFailure == true, state.error == erro
```

Ele guarda `status`, `data` e `error`. Repare que `setLoading()` **mantém** o `data` antigo: dá para mostrar a lista antiga enquanto atualiza.

## Passo 2: criar o controller

Crie `controllers/ranking_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/state/view_State.dart';
import '../../domain/entities/ranking_entry.dart';
import '../../domain/usecases/get_ranking_usecase.dart';

class RankingController extends ChangeNotifier {
  RankingController(this._getRanking);

  final GetRankingUseCase _getRanking;
  final ViewState<List<RankingEntry>> state = ViewState();

  Future<void> load() async {
    if (state.isLoading) return;          // evita chamadas duplicadas
    state.setLoading();
    notifyListeners();
    try {
      state.setSuccess(await _getRanking());
    } on AppException catch (e) {
      state.setFailure(e);
    } catch (e) {
      state.setFailure(UnexpectedException(cause: e));
    }
    notifyListeners();
  }
}
```

Perguntas para pensar:
- Por que chamamos `notifyListeners()` duas vezes? (Uma para mostrar o loading, outra para o resultado.)
- Por que o controller captura `AppException` separado de `catch (e)`? (A primeira já traz a mensagem da API; a segunda cobre bugs.)

## Passo 3: criar a página

Crie `pages/ranking_page.dart`. Ela recebe o controller e o id do usuário logado (para o destaque):

```dart
import 'package:flutter/material.dart';

import '../../domain/entities/ranking_entry.dart';
import '../controllers/ranking_controller.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, required this.controller, required this.currentUserId});

  final RankingController controller;
  final int currentUserId;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();               // carrega ao abrir
  }

  @override
  void dispose() {
    widget.controller.dispose();            // a pagina e dona do controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;

          if (state.isLoading && state.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.isFailure && state.data == null) {
            return _ErrorView(
              message: state.error?.message ?? 'Erro desconhecido',
              onRetry: widget.controller.load,
            );
          }
          final entries = state.data ?? const <RankingEntry>[];
          return RefreshIndicator(
            onRefresh: widget.controller.load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, i) => _RankingTile(
                position: i + 1,
                entry: entries[i],
                highlighted: entries[i].id == widget.currentUserId,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.position, required this.entry, required this.highlighted});

  final int position;
  final RankingEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: highlighted ? scheme.primaryContainer : null,
      leading: CircleAvatar(child: Text('$position')),
      title: Text(entry.nickname),
      trailing: Text('${entry.rankingPoints} pts'),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
```

Pontos importantes:
- O `ListView` usa `AlwaysScrollableScrollPhysics` para o "puxar para atualizar" funcionar mesmo com poucos itens.
- Os três estados (loading, erro, sucesso) são tratados na tela. Se esquecer um, o usuário vê tela vazia.
- Se já existe `data` e ocorre erro ao atualizar, a lista antiga continua visível.

## Passo 4: ligar na Home

No `home_page.dart`, troque o marcador do ranking:

```dart
onTap: () => _open(
  context,
  RankingPage(
    controller: RankingController(deps.getRanking),
    currentUserId: session.user.id,
  ),
),
```

(`deps.getRanking` vem do `AppDependencies`; veja o tutorial da Home.)

## Passo 5: testar

1. Com a API rodando, abra o ranking: deve aparecer a lista ordenada por pontos, com você destacado.
2. Pare a API e puxe para atualizar: a lista antiga fica e o erro aparece se não houver dados. Recarregue sem dados: aparece a mensagem com "Tentar novamente".
3. Faça um teste do controller com um `GetRankingUseCase` falso: a sequência deve ser `loading`, depois `success`.

## Armadilhas comuns

- Esquecer `widget.controller.load()` no `initState`: a tela abre vazia.
- Chamar `load()` dentro do `build`: cria um loop infinito de requisições.
- Não fazer `dispose` do controller: vazamento de memória.
- Usar `entry.id` para comparar com o usuário: correto aqui, porque `RankingEntry.id` e `PlayerUser.id` são o mesmo id de usuário. (Não confunda com `GamePlayer.id`, que é o id dentro de uma partida.)

## Exercícios

1. Mostre medalhas (🥇🥈🥉) nas três primeiras posições.
2. Trate empates: jogadores com os mesmos pontos devem mostrar a mesma posição.
3. Adicione um campo de busca por apelido que filtra a lista localmente.
