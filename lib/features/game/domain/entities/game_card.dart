import '../enums/card_suit.dart';
import '../enums/card_value.dart';
import '../enums/skill_type.dart';

final class GameCard {
  /// Presente so nas cartas da propria mao; unico ID aceito ao jogar.
  final int? handCardId;
  final int catalogCardId;
  final CardValue valor;
  final CardSuit naipe;
  final SkillType? skill;

  const GameCard({
    this.handCardId,
    required this.catalogCardId,
    required this.valor,
    required this.naipe,
    this.skill,
  });
}
