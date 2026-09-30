# Guia do Profile

## Antes de criar a tela

`lib/features/profile/` ainda não existe. Crie `presentation/profile_page.dart` (e `presentation/controllers/profile_controller.dart` se for atualizar dados). O contrato atual não define endpoint de perfil, edição de usuário, avatar ou saldo permanente. Os dados confiáveis para esta tela são:

- `session.user.id` e `session.user.nickname`, obtidos no login e restaurados por `SessionRepositoryImpl`;
- `session.user.rankingPoints`, valor recebido no login;
- `RankingEntry.rankingPoints` e a posição atual, obtidos de `GET /users/ranking` por `GetRankingUseCase`.

Não crie botões de editar apelido, enviar avatar ou endpoints fictícios. As moedas e troféus em `GamePlayer` pertencem a uma partida, não ao perfil global.

## 1. Desenhe a primeira versão

Faça `ProfilePage` receber `AuthSession session`, `GetRankingUseCase getRanking` e `Future<void> Function() onLogout`. Mostre o apelido e o ID da sessão imediatamente; use `session.user.rankingPoints` como pontuação inicial. Mostre um indicador de carregamento enquanto consulta a pontuação recente. Um botão **Sair** chama `onLogout`, que já limpa a sessão no `main.dart` por `ClearSessionUseCase`.

```dart
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.getRanking,
    required this.onLogout,
  });

  final AuthSession session;
  final GetRankingUseCase getRanking;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}
```

Se a página for filha da dock, devolva apenas o conteúdo da aba e deixe `Scaffold`/`NavigationBar` no contêiner. Use `SafeArea` e `ListView` para acomodar telas pequenas.

## 2. Atualize os pontos pela API existente

No `initState`, chame um método `_refresh`. Ele carrega o ranking, procura o usuário por **ID** e calcula a posição a partir do índice da resposta. Não procure pelo apelido: ele é texto de exibição. Não use `GamePlayer.id`.

```dart
Future<void> _refresh() async {
  setState(() { _loading = true; _error = null; });
  try {
    final entries = await widget.getRanking();
    final index = entries.indexWhere((e) => e.id == widget.session.user.id);
    if (!mounted) return;
    setState(() {
      _points = index < 0
          ? widget.session.user.rankingPoints
          : entries[index].rankingPoints;
      _position = index < 0 ? null : index + 1;
    });
  } on AppException catch (error) {
    if (mounted) setState(() => _error = error.message);
  } catch (_) {
    if (mounted) setState(() => _error = const UnexpectedException().message);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

Declare `_loading`, `_error`, `_points` e `_position` no `State`, inicializando `_points` com `widget.session.user.rankingPoints` em `initState`. O trecho acima é o núcleo da busca; importe `AppException` e `UnexpectedException` de `core/error/app_exception.dart`. Se a entrada não aparecer no ranking, mostre "Posição indisponível"; não confunda ausência com último lugar.

Mostre o erro de atualização junto dos dados da sessão e um botão **Tentar novamente**. Use `RefreshIndicator` para recarregar ao puxar, ou um botão explícito. Não faça a requisição em `build`.

## 3. Encaixe na navegação e sessão

No contêiner autenticado, monte `GetRankingUseCase(RankingRepositoryImpl(_api))` uma vez e passe à página. Reutilize o callback `_logout` do `main.dart`; ele chama `ClearSessionUseCase`, zera `_session` e mostra o login. Em um `401`, o próprio `ApiClient.onUnauthorized` já executa esse fluxo. Como o login está fora da dock, um logout deve remover todas as abas e qualquer controller de partida ativo.

## 4. Verifique

1. Abra Profile após login: apelido e ID devem aparecer mesmo se a rede falhar.
2. Atualize: confira pontuação e posição contra `GET /users/ranking`.
3. Desligue a API e tente atualizar: a mensagem de erro aparece e os dados anteriores continuam visíveis.
4. Toque em **Sair** e reabra o app: o login deve aparecer novamente.

Veja [Ranking](../ranking/guia.md) para o mesmo endpoint e [dock](../../../guia_dock.md) para adicionar a aba.
