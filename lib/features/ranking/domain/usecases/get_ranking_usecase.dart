import '../entities/ranking_entry.dart';
import '../repositories/ranking_repository.dart';

final class GetRankingUseCase {
  final RankingRepository _repository;

  const GetRankingUseCase(this._repository);

  Future<List<RankingEntry>> call() => _repository.listRanking();
}
