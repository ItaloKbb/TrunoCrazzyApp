import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../ranking/domain/usecases/get_ranking_usecase.dart';
import '../state/profile_state.dart';

class ProfileController extends ChangeNotifier {
  final GetRankingUseCase _getRanking;

  ProfileState _state;
  Profil
}