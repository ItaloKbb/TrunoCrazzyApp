import '../entities/skill_definition.dart';

abstract interface class SkillCatalogRepository {
  /// GET /skills
  Future<List<SkillDefinition>> listSkills();
}
