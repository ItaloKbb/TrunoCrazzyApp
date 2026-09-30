import '../entities/skill_definition.dart';
import '../repositories/skill_catalog_repository.dart';

final class ListSkillsUseCase {
  final SkillCatalogRepository _repository;

  const ListSkillsUseCase(this._repository);

  Future<List<SkillDefinition>> call() => _repository.listSkills();
}
