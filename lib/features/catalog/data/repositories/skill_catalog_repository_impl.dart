import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_parsing.dart';
import '../../domain/entities/skill_definition.dart';
import '../../domain/repositories/skill_catalog_repository.dart';
import '../mappers/catalog_mapper.dart';

final class SkillCatalogRepositoryImpl implements SkillCatalogRepository {
  final ApiClient _api;

  const SkillCatalogRepositoryImpl(this._api);

  @override
  Future<List<SkillDefinition>> listSkills() async =>
      parseList(await _api.get('/skills'), CatalogMapper.skill);
}
