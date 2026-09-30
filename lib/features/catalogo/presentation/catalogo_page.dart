import 'package:flutter/material.dart';

import '../../../core/error/app_exception.dart';
import '../../catalog/domain/entities/catalog_card.dart';
import '../../catalog/domain/usecases/list_cards_usecase.dart';
import '../../game/domain/enums/card_suit.dart';
import '../../game/domain/enums/card_value.dart';

/// Baralho oficial vindo de `GET /cards`.
class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key, required this.listCards});

  final ListCardsUseCase listCards;

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  CardSuit? naipeSelecionado;
  late Future<List<CatalogCard>> _cartas;

  @override
  void initState() {
    super.initState();
    _cartas = widget.listCards();
  }

  void _recarregar() => setState(() => _cartas = widget.listCards());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Baralho de Truco')),
      body: FutureBuilder<List<CatalogCard>>(
        future: _cartas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is AppException
                          ? error.message
                          : const UnexpectedException().message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _recarregar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final todas = snapshot.data ?? const <CatalogCard>[];
          final cartas = naipeSelecionado == null
              ? todas
              : todas.where((c) => c.naipe == naipeSelecionado).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: naipeSelecionado == null,
                      onSelected: (_) =>
                          setState(() => naipeSelecionado = null),
                    ),
                    ...CardSuit.values.map(
                      (naipe) => ChoiceChip(
                        label: Text('${_simboloNaipe(naipe)} ${_nomeNaipe(naipe)}'),
                        selected: naipeSelecionado == naipe,
                        onSelected: (_) =>
                            setState(() => naipeSelecionado = naipe),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: .7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cartas.length,
                  itemBuilder: (context, index) =>
                      _CartaWidget(carta: cartas[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartaWidget extends StatelessWidget {
  const _CartaWidget({required this.carta});

  final CatalogCard carta;

  @override
  Widget build(BuildContext context) {
    final vermelha = carta.naipe == CardSuit.copas || carta.naipe == CardSuit.ouros;
    final cor = vermelha ? Colors.red : Colors.black;
    final valor = _simboloValor(carta.valor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: TextStyle(fontSize: 24, color: cor)),
            const Spacer(),
            Center(
              child: Text(
                _simboloNaipe(carta.naipe),
                style: TextStyle(fontSize: 34, color: cor),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(valor, style: TextStyle(fontSize: 18, color: cor)),
            ),
          ],
        ),
      ),
    );
  }
}

String _simboloNaipe(CardSuit s) => switch (s) {
      CardSuit.paus => '♣',
      CardSuit.copas => '♥',
      CardSuit.espadas => '♠',
      CardSuit.ouros => '♦',
    };

String _nomeNaipe(CardSuit s) => switch (s) {
      CardSuit.paus => 'Paus',
      CardSuit.copas => 'Copas',
      CardSuit.espadas => 'Espadas',
      CardSuit.ouros => 'Ouros',
    };

String _simboloValor(CardValue v) => switch (v) {
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
