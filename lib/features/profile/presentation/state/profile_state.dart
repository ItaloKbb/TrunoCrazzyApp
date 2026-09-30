import '../../../../core/error/app_exception.dart';
import '../../../auth/domain/entities/auth_session.dart';

enum ProfileStatus { idle, loading, success, failure }

final class ProfileState {
  final ProfileStatus status;
  final AuthSession session;
  final int points;
  final int? position;
  final AppException? error;

  const ProfileState._({
    required this.status,
    required this.session,
    required this.points,
    this.position,
    this.error,
  });

  ProfileState.idle(AuthSession session)
      : this._(
        status: ProfileStatus.idle,
        session: session,
        points: session.user.rankingPoints,
      );
    
  ProfileState loading() => ProfileState._(
        status: ProfileStatus.loading,
        session: session,
        points: points,
        position: position,
  );

  ProfileState success({required int points, required int? position}) =>
      ProfileState._(
        status: ProfileStatus.success,
        session: session,
        points: points,
        position: position,
      );

  ProfileState failure(AppException error) => ProfileState._(
        status: ProfileStatus.failure,
        session: session,
        points: points,
        position: position,
        error: error,
  );

  bool get isLoading => status == ProfileStatus.loading;
  bool get hasPosition => position != null;
}
