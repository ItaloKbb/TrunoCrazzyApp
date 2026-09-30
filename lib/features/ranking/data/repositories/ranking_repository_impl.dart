import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_parsing.dart';
import '../../domain/entities/ranking_entry.dart';
import '../../domain/repositories/ranking_repository.dart';

final class RankingRepositoryImpl implements RankingRepository {
  final ApiClient _api;

  const RankingRepositoryImpl(this._api);

  @override
  Future<List<RankingEntry>> listRanking() async =>
      parseList(await _api.get('/users/ranking'), (j) => RankingEntry(
            id: (j['id'] as num).toInt(),
            nickname: j['nickname'] as String,
            rankingPoints: (j['rankingPoints'] as num).toInt(),
          ));
}
