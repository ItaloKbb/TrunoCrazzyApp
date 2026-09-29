# Tutorial: criando a tela de Catálogo (cartas, skills e puzzles)

**Objetivo:** uma tela com três abas que lista o que a API oferece: **Cartas** (`GET /cards`), **Skills** (`GET /skills`) e **Puzzles** (`GET /puzzles`).

**Pré-requisitos (já existem):** `CatalogCard`, `SkillDefinition`, `PuzzleDefinition`, os casos de uso `ListCardsUseCase`, `ListSkillsUseCase`, `ListPuzzlesUseCase` e seus `*Impl`.

**Arquivos que você vai criar:**

```text
lib/core/ui/formatters/card_labels.dart            (texto/símbolo das cartas, reaproveitado no jogo)
lib/features/catalog/presentation/
  controllers/catalog_controller.dart
  pages/catalog_page.dart
  widgets/card_tile.dart
```

---

## Passo 1: traduzir enums em texto para a tela

O domínio tem `CardSuit.ouros` e `CardValue.dama`. A tela precisa de "♦" e "Q". Isso é responsabilidade da **presentation**, então usamos extensions.

Crie `lib/core/ui/formatters/card_labels.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../features/game/domain/enums/card_suit.dart';
import '../../../features/game/domain/enums/card_value.dart';

extension CardSuitLabel on CardSuit {
  String get symbol => switch (this) {
        CardSuit.ouros => '♦',
        CardSuit.espadas => '♠',
        CardSuit.copas => '♥',
        CardSuit.paus => '♣',
      };

  String get label => switch (this) {
        CardSuit.ouros => 'Ouros',
        CardSuit.espadas => 'Espadas',
        CardSuit.copas => 'Copas',
        CardSuit.paus => 'Paus',
      };

  Color get color =>
      (this == CardSuit.ouros || this == CardSuit.copas) ? Colors.red : Colors.black;
}

extension CardValueLabel on CardValue {
  String get symbol => switch (this) {
        CardValue.as => 'A',
        CardValue.dois => '2',
        CardValue.tres => '3',
        CardValue.quatro => '4',
        CardValue.cinco => '5',
        CardValue.seis => '6',
        CardValue.sete => '7',
        CardValue.dama => 'Q',
        CardValue.valete => 'J',
        CardValue.rei => 'K',
      };
}
```

O `switch` como expressão do Dart 3 obriga a cobrir **todos** os valores do enum: se alguém adicionar um naipe, o compilador avisa.

## Passo 2: o controller com três listas

Uma tela, três requisições independentes. Use um `ViewState` para cada uma.

`controllers/catalog_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/ui/state/view_State.dart';
import '../../domain/entities/catalog_card.dart';
import '../../domain/entities/puzzle_definition.dart';
import '../../domain/entities/skill_definition.dart';
import '../../domain/usecases/list_cards_usecase.dart';
import '../../domain/usecases/list_puzzles_usecase.dart';
import '../../domain/usecases/list_skills_usecase.dart';

class CatalogController extends ChangeNotifier {
  CatalogController({
    required ListCardsUseCase listCards,
    required ListSkillsUseCase listSkills,
    required ListPuzzlesUseCase listPuzzles,
  })  : _listCards = listCards,
        _listSkills = listSkills,
        _listPuzzles = listPuzzles;

  final ListCardsUseCase _listCards;
  final ListSkillsUseCase _listSkills;
  final ListPuzzlesUseCase _listPuzzles;

  final cards = ViewState<List<CatalogCard>>();
  final skills = ViewState<List<SkillDefinition>>();
  final puzzles = ViewState<List<PuzzleDefinition>>();

  Future<void> loadAll() => Future.wait([
        _run(cards, _listCards.call),
        _run(skills, _listSkills.call),
        _run(puzzles, _listPuzzles.call),
      ]);

  /// Padrao repetido: loading -> resultado. Escrito uma vez e reutilizado.
  Future<void> _run<T>(ViewState<T> state, Future<T> Function() action) async {
    state.setLoading();
    notifyListeners();
    try {
      state.setSuccess(await action());
    } on AppException catch (e) {
      state.setFailure(e);
    } catch (e) {
      state.setFailure(UnexpectedException(cause: e));
    }
    notifyListeners();
  }
}
```

`Future.wait` dispara as três requisições ao mesmo tempo. Se uma falhar, as outras continuam: cada aba mostra seu próprio erro.

## Passo 3: um widget de carta reutilizável

`widgets/card_tile.dart` (será usado também na mão do jogador, por isso recebe valores simples):

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/formatters/card_labels.dart';
import '../../../game/domain/enums/card_suit.dart';
import '../../../game/domain/enums/card_value.dart';

class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.valor, required this.naipe, this.onTap});

  final CardValue valor;
  final CardSuit naipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = naipe.color;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor.symbol, style: TextStyle(fontSize: 22, color: color)),
              const Spacer(),
              Center(child: Text(naipe.symbol, style: TextStyle(fontSize: 32, color: color))),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Passo 4: a página com abas

`pages/catalog_page.dart`:

```dart
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.controller});
  final CatalogController controller;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadAll();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catalogo'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Cartas'),
            Tab(text: 'Skills'),
            Tab(text: 'Puzzles'),
          ]),
        ),
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            return TabBarView(children: [
              _StateView<List<CatalogCard>>(
                state: c.cards,
                onRetry: c.loadAll,
                builder: (cards) => GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 110,
                    childAspectRatio: .7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (_, i) => CardTile(valor: cards[i].valor, naipe: cards[i].naipe),
                ),
              ),
              _StateView<List<SkillDefinition>>(
                state: c.skills,
                onRetry: c.loadAll,
                builder: (skills) => ListView(
                  children: [
                    for (final s in skills)
                      ListTile(
                        title: Text(s.name),
                        subtitle: Text(s.description),
                        trailing: Text('${s.valor.symbol}${s.naipe.symbol}'),
                      ),
                  ],
                ),
              ),
              _StateView<List<PuzzleDefinition>>(
                state: c.puzzles,
                onRetry: c.loadAll,
                builder: (puzzles) => ListView(
                  children: [
                    for (final p in puzzles)
                      ExpansionTile(
                        title: Text(p.question),
                        children: [for (final a in p.alternatives) ListTile(title: Text(a))],
                      ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
```

### O widget `_StateView<T>` (evita repetir if/else três vezes)

```dart
class _StateView<T> extends StatelessWidget {
  const _StateView({required this.state, required this.builder, required this.onRetry});

  final ViewState<T> state;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    if (data != null) return builder(data);
    if (state.isFailure) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(state.error?.message ?? 'Erro'),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ]),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
```

Note que os puzzles **não mostram a resposta correta**: a API nem a envia. Quem valida é o servidor.

## Passo 5: ligar na Home

```dart
onTap: () => _open(
  context,
  CatalogPage(
    controller: CatalogController(
      listCards: deps.listCards,
      listSkills: deps.listSkills,
      listPuzzles: deps.listPuzzles,
    ),
  ),
),
```

## Passo 6: testar

1. As três abas carregam sem travar as outras.
2. Pare a API: cada aba mostra a mensagem e "Tentar novamente".
3. Confira que há 40 cartas (10 valores x 4 naipes) e que as vermelhas são copas e ouros.

## Exercícios

1. Adicione filtro por naipe na aba de cartas (como o `ChoiceChip` da versão offline em `features/catalogo`).
2. Na aba de skills, mostre o ícone do tipo (`SkillType`) usando um `switch` como o de `CardSuitLabel`.
3. Ao tocar em uma carta, abra um dialog com o valor e o naipe por extenso ("Dama de Copas").
4. Substitua o `catalogo` offline por esta tela e remova `baralho_truco.dart`.
