# Tutorial: o Catálogo offline (versão de demonstração)

> Esta feature é a **versão inicial** do baralho, com dados locais e sem API. Ela serve para aprender as camadas antes de falar com o servidor. A versão final, com a API, está em `features/catalog` (sem o "o" no final).

**Objetivo:** mostrar as 40 cartas do baralho de Truco em uma grade, com filtro por naipe.

**Estrutura da feature:**

```text
features/catalogo/
  domain/carta_truco.dart              <- Naipe, ValorCarta, CartaTruco
  data/baralho_truco.dart              <- a lista const com as 40 cartas
  data/services/baralho_truco_service.dart
  data/repositories/catalogo_repository.dart
  presentation/catalogo_page.dart
```

Aqui o fluxo é curto: `CatalogoPage -> CatalogoRepository -> BaralhoTrucoService -> lista const`. Nada é assíncrono, então não há loading nem erro.

---

## Passo 1: o modelo (domain)

Em `carta_truco.dart`, dois enums e uma classe:

```dart
enum Naipe {
  paus('Paus', '♣'),
  copas('Copas', '♥'),
  espadas('Espadas', '♠'),
  ouros('Ouros', '♦');

  const Naipe(this.nome, this.simbolo);
  final String nome;
  final String simbolo;
}

class CartaTruco {
  const CartaTruco({required this.valor, required this.naipe});
  final ValorCarta valor;
  final Naipe naipe;
}
```

Conceito: **enum com campos**. Em vez de um `switch` para cada símbolo, o símbolo mora dentro do enum.

## Passo 2: os dados (data)

`baralho_truco.dart` é uma lista `const` de `CartaTruco`. O `BaralhoTrucoService` devolve essa lista, e o `CatalogoRepository` chama o service:

```dart
class CatalogoRepository {
  const CatalogoRepository({this.service = const BaralhoTrucoService()});
  final BaralhoTrucoService service;

  List<CartaTruco> buscarCartas() => service.buscarCartas();
}
```

Por que três camadas para devolver uma lista? Porque **a tela não sabe de onde vêm as cartas**. Quando a API chegar, só o service muda.

## Passo 3: a página (presentation)

A página é um `StatefulWidget` com **um único estado local**: o naipe selecionado.

```dart
class _CatalogoPageState extends State<CatalogoPage> {
  Naipe? naipeSelecionado;          // null = todos

  @override
  Widget build(BuildContext context) {
    final todas = widget.repository.buscarCartas();
    final cartas = naipeSelecionado == null
        ? todas
        : todas.where((c) => c.naipe == naipeSelecionado).toList();
    ...
  }
}
```

### 3.1 Filtro com `ChoiceChip`

```dart
ChoiceChip(
  label: const Text('Todos'),
  selected: naipeSelecionado == null,
  onSelected: (_) => setState(() => naipeSelecionado = null),
),
...Naipe.values.map((naipe) => ChoiceChip(
      label: Text('${naipe.simbolo} ${naipe.nome}'),
      selected: naipeSelecionado == naipe,
      onSelected: (_) => setState(() => naipeSelecionado = naipe),
    )),
```

`Naipe.values` gera um chip por naipe. Se um novo naipe fosse criado, o chip apareceria sozinho.

### 3.2 Grade com `GridView.builder`

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    childAspectRatio: .7,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemCount: cartas.length,
  itemBuilder: (context, index) => _CartaWidget(carta: cartas[index]),
)
```

O `.builder` só constrói os itens visíveis, então continua rápido com listas grandes.

### 3.3 O widget da carta

`_CartaWidget` é privado (começa com `_`): só existe nesta página. Ele usa `Card` + `Column` com `Spacer` para posicionar o valor no topo, o naipe no centro e o valor de novo embaixo. Copas e ouros são vermelhos:

```dart
final vermelha = carta.naipe == Naipe.copas || carta.naipe == Naipe.ouros;
final cor = vermelha ? Colors.red : Colors.black;
```

## Passo 4: testar

1. `flutter run` e abra o catálogo: 40 cartas.
2. Toque em "Copas": só 10 cartas, todas vermelhas.
3. Toque em "Todos": voltam as 40.

## O que aprender daqui

| Conceito | Onde aparece |
|---|---|
| Enum com campos | `Naipe`, `ValorCarta` |
| Estado local (`setState`) | filtro por naipe |
| Dado derivado no `build` | `cartas` calculada a partir de `todas` |
| Widget privado | `_CartaWidget` |
| Injeção com valor padrão | `CatalogoRepository` recebido no construtor com `const` default |

## Limitações (por que existe a versão com API)

- As cartas são fixas no app; o servidor tem os ids reais (`catalogCardId`) e as skills.
- Sem `id`, não dá para relacionar uma carta à do jogo.
- Sem controller: para chamar a API precisaremos de estados de loading e erro.

## Exercícios

1. Adicione ordenação: mostre as cartas na ordem de força do Truco (`4, 5, 6, 7, Q, J, K, A, 2, 3`).
2. Extraia `_CartaWidget` para um arquivo `widgets/carta_widget.dart`.
3. Migre a página para o `CatalogController` da feature `catalog` e apague `data/` desta feature.
