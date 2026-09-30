import '../entities/ranking_entry.dart';

abstract interface class RankingRepository {
  /// GET /users/ranking
  Future<List<RankingEntry>> listRanking();
}
