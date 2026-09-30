import '../../../game/data/mappers/enum_mappers.dart';
import '../../domain/entities/catalog_card.dart';
import '../../domain/entities/puzzle_definition.dart';
import '../../domain/entities/skill_definition.dart';

typedef Json = Map<String, dynamic>;

/// JSON dos catalogos -> entidades. Chaves da API: `valor`, `naipe`
/// e, no puzzle publico, `alternativas` (com "s" no final, em portugues).
abstract final class CatalogMapper {
  static CatalogCard card(Json j) => CatalogCard(
        id: (j['id'] as num).toInt(),
        valor: EnumMappers.cardValue(j['valor']),
        naipe: EnumMappers.cardSuit(j['naipe']),
      );

  static SkillDefinition skill(Json j) => SkillDefinition(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        description: j['description'] as String,
        type: EnumMappers.skillType(j['type']),
        naipe: EnumMappers.cardSuit(j['naipe']),
        valor: EnumMappers.cardValue(j['valor']),
      );

  static PuzzleDefinition puzzle(Json j) => PuzzleDefinition(
        id: (j['id'] as num).toInt(),
        question: j['question'] as String,
        alternatives: (j['alternativas'] as List).cast<String>(),
      );
}
