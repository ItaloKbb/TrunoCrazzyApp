import '../../../game/domain/enums/card_suit.dart';
import '../../../game/domain/enums/card_value.dart';
import '../../../game/domain/enums/skill_type.dart';

final class SkillDefinition {
  final int id;
  final String name;
  final String description;
  final SkillType type;
  final CardSuit suit;
  final CardValue value;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.suit,
    required this.value,
  });
}
