import '../../../game/domain/enums/card_suit.dart';
import '../../../game/domain/enums/card_value.dart';
import '../../../game/domain/enums/skill_type.dart';

final class SkillDefinition {
  final int id;
  final String name;
  final String description;
  final SkillType type;
  final CardSuit naipe;
  final CardValue valor;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.naipe,
    required this.valor,
  });
}
