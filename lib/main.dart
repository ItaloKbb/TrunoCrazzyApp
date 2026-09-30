import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/session_repository_impl.dart';
import 'features/auth/domain/entities/auth_session.dart';
import 'features/auth/domain/usecases/clear_session_usecase.dart';
import 'features/auth/domain/usecases/get_current_session_usecase.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/controllers/login_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/catalog/data/repositories/card_catalog_repository_impl.dart';
import 'features/catalog/domain/usecases/list_cards_usecase.dart';
import 'features/home/presentation/home_page.dart';

void main() => runApp(const TrunoCrazyApp());

class TrunoCrazyApp extends StatefulWidget {
  const TrunoCrazyApp({super.key});

  @override
  State<TrunoCrazyApp> createState() => _TrunoCrazyAppState();
}

class _TrunoCrazyAppState extends State<TrunoCrazyApp> {
  late final SessionRepositoryImpl _sessions;
  late final ApiClient _api;
  late final LoginUseCase _login;
  late final GetCurrentSessionUseCase _getSession;
  late final ClearSessionUseCase _clearSession;
  late final ListCardsUseCase _listCards;

  AuthSession? _session;
  bool _loading = true;
  LoginController? _loginController;

  @override
  void initState() {
    super.initState();
    _sessions = const SessionRepositoryImpl();
    _api = ApiClient(
      tokenProvider: () async => (await _sessions.getCurrentSession())?.token,
      onUnauthorized: _logout,
    );
    _login = LoginUseCase(AuthRepositoryImpl(_api), _sessions);
    _getSession = GetCurrentSessionUseCase(_sessions);
    _clearSession = ClearSessionUseCase(_sessions);
    _listCards = ListCardsUseCase(CardCatalogRepositoryImpl(_api));
    _restore();
  }

  Future<void> _restore() async {
    final session = await _getSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
      _loginController = LoginController(_login);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_loading) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_session == null) {
      _loginController ??= LoginController(_login);
      home = LoginPage(
        controller: _loginController!,
        onLoggedIn: (session) => setState(() => _session = session),
      );
    } else {
      home = HomePage(
        session: _session!,
        onLogout: _logout,
        listCards: _listCards,
      );
    }

    return MaterialApp(
      title: 'TrunoCrazy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C1906)),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
