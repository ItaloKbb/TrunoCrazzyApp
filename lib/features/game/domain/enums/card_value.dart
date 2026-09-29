enum CardValue {
  as,
  dois,
  tres,
  quatro,
  cinco,
  seis,
  sete,
  dama,
  valete,
  rei;

  /// Ordem do jogo, apenas para exibicao da sequencia.
  static const List<CardValue> gameOrder = [
    quatro,
    cinco,
    seis,
    sete,
    dama,
    valete,
    rei,
    as,
    dois,
    tres,
  ];
}
