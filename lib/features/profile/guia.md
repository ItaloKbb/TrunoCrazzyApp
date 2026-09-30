# Guia do Profile (passo a passo)

Neste guia você cria a tela de **Perfil** seguindo o mesmo padrão da feature Auth: **state → controller → page**. Leia antes o [tutorial de presentation do Auth](../auth/presentation/index.md): ele explica o porquê de cada camada. Aqui o foco é o passo a passo.

## O que o Profile mostra (e o que não mostra)

O contrato da API **não** tem endpoint de perfil, edição de apelido, avatar ou saldo permanente. Não crie botões nem endpoints fictícios. Os dados confiáveis são:

| Dado | De onde vem |
|---|---|
| `session.user.id` e `session.user.nickname` | Login, restaurados por `SessionRepositoryImpl` |
| `session.user.rankingPoints` | Valor recebido no login (pode estar desatualizado) |
| Pontuação atual e posição | `GET /users/ranking`, via `GetRankingUseCase` |

As moedas e troféus de `GamePlayer` pertencem a **uma partida**, não ao perfil. Não use `GamePlayer.id` aqui.

## Por que não precisa de domain nem data

O domain e a data do Profile **já existem**: `GetRankingUseCase`, `RankingRepository` e `RankingRepositoryImpl` (feature `ranking`), e `AuthSession`/`PlayerUser` (feature `auth`). Falta só a **presentation**.

## Estrutura de pastas

`lib/features/profile/` ainda não tem código. Crie:

```text
lib/features/profile/presentation/
  state/        profile_state.dart        <- o "retrato" da tela
  controllers/  profile_controller.dart   <- a lógica da tela
  pages/        profile_page.dart         <- os widgets
```

Siga a ordem de dependência: **state, controller, page, e por fim o `main.dart`**.

---

## Passo 1: o State

Arquivo: `state/profile_state.dart`

### 1.1 Decida o que a tela precisa saber

- `status`: `idle`, `loading`, `success` ou `failure`;
- `session`: o usuário logado. **Sempre existe**, então apelido e ID aparecem mesmo sem rede;
- `points`: pontuação exibida (começa com a do login);
- `position`: posição no ranking, ou `null` se o usuário não aparecer na lista;
- `error`: a falha da última atualização, se houver.

Ponto importante: em `loading` e `failure` os **dados anteriores continuam** no estado. Assim a tela não "esvazia" quando a rede cai.

### 1.2 Escreva o arquivo

```dart
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

  /// Estado inicial: usa a pontuação recebida no login.
  ProfileState.idle(AuthSession session)
      : this._(
          status: ProfileStatus.idle,
          session: session,
          points: session.user.rankingPoints,
        );

  /// Mantém pontos e posição anteriores enquanto consulta.
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

  /// Mantém os últimos dados e acrescenta o erro.
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
```

### 1.3 Por que é assim

- **Construtor privado `_`:** ninguém de fora cria um estado inconsistente.
- **Métodos `loading()`, `success()` e `failure()`:** em vez de construtores nomeados como no `LoginState`, eles partem do estado atual e **copiam** `session`, `points` e `position`. É isso que preserva os dados anteriores.
- **`ProfileState.idle(session)` não é `const`:** ele lê `session.user.rankingPoints`, que não é constante.
- O state **não tem lógica de negócio**: só descreve a tela.

✅ **Confira:** o arquivo compila sozinho (nenhum import de Flutter). Nada de `ChangeNotifier` aqui.

---

## Passo 2: o Controller

Arquivo: `controllers/profile_controller.dart`

### 2.1 Responsabilidade

Receber a ação da tela (`refresh`), chamar o caso de uso e **traduzir o resultado em estado**. Não usa `BuildContext`, não faz HTTP e não navega.

### 2.2 Escreva o arquivo

```dart
import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../ranking/domain/usecases/get_ranking_usecase.dart';
import '../state/profile_state.dart';

class ProfileController extends ChangeNotifier {
  final GetRankingUseCase _getRanking;

  ProfileController(this._getRanking, AuthSession session)
      : _state = ProfileState.idle(session);

  ProfileState _state;
  ProfileState get state => _state;

  Future<void> refresh() async {
    if (_state.isLoading) return;                              // 1
    _emit(_state.loading());                                   // 2
    try {
      final entries = await _getRanking();                     // 3
      final index =
          entries.indexWhere((e) => e.id == _state.session.user.id);
      _emit(_state.success(                                    // 4
        points: index < 0
            ? _state.session.user.rankingPoints
            : entries[index].rankingPoints,
        position: index < 0 ? null : index + 1,
      ));
    } on AppException catch (e) {
      _emit(_state.failure(e));                                // 5
    } catch (e) {
      _emit(_state.failure(UnexpectedException(cause: e)));
    }
  }

  void _emit(ProfileState state) {
    _state = state;
    notifyListeners();                                         // 6
  }
}
```

### 2.3 Passo a passo do `refresh`

1. **Evita chamadas duplicadas:** se já está carregando, ignora (puxar a tela duas vezes não dispara duas requisições).
2. **Emite `loading`:** a tela mostra o indicador, mas pontos e posição antigos continuam visíveis.
3. **Chama o caso de uso:** `GetRankingUseCase` devolve `List<RankingEntry>`.
4. **Procura o usuário por ID** (`e.id == session.user.id`). **Não** procure pelo apelido (é texto de exibição) e **não** use `GamePlayer.id` (são IDs diferentes). A posição é `index + 1`. Se não achar (`index < 0`), os pontos vêm da sessão e `position` fica `null`. Ausência **não** é último lugar.
5. **Traduz exceções em estado:** `AppException` (401, 404, rede...) vira `failure` com a mensagem da API; qualquer outro erro vira `UnexpectedException`.
6. **`notifyListeners()`** avisa a tela.

✅ **Confira:** não há `import 'package:flutter/material.dart'` (só `foundation.dart`). O controller é testável com um `GetRankingUseCase` falso.

---

## Passo 3: a Page

Arquivo: `pages/profile_page.dart`

### 3.1 Responsabilidade

Desenhar o estado atual e repassar as ações ao controller. Ela recebe tudo **de fora**: nada de criar repositório ou `ApiClient` dentro da página.

### 3.2 Esqueleto: construtor e ciclo de vida

```dart
import 'package:flutter/material.dart';

import '../controllers/profile_controller.dart';
import '../state/profile_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.onLogout,
  });

  final ProfileController controller;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();   // nunca faça requisição dentro do build
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
  ...
}
```

Se for você quem cria o controller (passo 4), a página é quem o descarta no `dispose`. Se o criador o mantiver vivo (por exemplo, ao trocar de aba da dock), **não** chame `dispose` aqui e faça o dono descartá-lo.

### 3.3 Ouvir o estado com `ListenableBuilder`

```dart
@override
Widget build(BuildContext context) {
  return SafeArea(
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // blocos dos passos 3.4 a 3.7
            ],
          ),
        );
      },
    ),
  );
}
```

- `ListView` dentro do `RefreshIndicator` permite **puxar para atualizar** e acomoda telas pequenas (o `ListView` precisa ser rolável; com poucos itens, use `physics: const AlwaysScrollableScrollPhysics()`).
- Se a página for filha da dock, devolva **só o conteúdo**: `Scaffold` e `NavigationBar` ficam no contêiner (veja a [dock](../../../guia_dock.md)). Não aninhe `Scaffold`s.

### 3.4 Bloco: identificação (aparece sempre)

```dart
ListTile(
  leading: const CircleAvatar(child: Icon(Icons.person)),
  title: Text(state.session.user.nickname),
  subtitle: Text('ID ${state.session.user.id}'),
),
```

### 3.5 Bloco: pontuação e posição

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text('${state.points} pontos',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(state.hasPosition
            ? '${state.position}º no ranking'
            : 'Posição indisponível'),
      ],
    ),
  ),
),
```

### 3.6 Bloco: carregando e erro

```dart
if (state.isLoading) const LinearProgressIndicator(),
if (state.status == ProfileStatus.failure) ...[
  const SizedBox(height: 8),
  Text(
    state.error?.message ?? '',
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  ),
  TextButton(
    onPressed: widget.controller.refresh,
    child: const Text('Tentar novamente'),
  ),
],
```

Não existe `setState` para loading ou erro: a tela só **lê** o estado.

### 3.7 Bloco: sair

```dart
const SizedBox(height: 24),
OutlinedButton.icon(
  onPressed: widget.onLogout,
  icon: const Icon(Icons.logout),
  label: const Text('Sair'),
),
```

`onLogout` é o `_logout` do `main.dart`, que já chama `ClearSessionUseCase`.

✅ **Confira:** a página não importa nada de `data/` nem `ApiClient`. Só o controller, o state e o Flutter.

---

## Passo 4: montar no `main.dart` (composition root)

No mesmo lugar onde o `main.dart` cria `_api` e os outros casos de uso, monte **uma vez**:

```dart
final getRanking = GetRankingUseCase(RankingRepositoryImpl(_api));
```

Onde o contêiner autenticado monta as abas, crie o controller e entregue à página:

```dart
ProfilePage(
  controller: ProfileController(getRanking, session),
  onLogout: _logout,
)
```

Regras:

- Declare `getRanking` como campo (ou em um objeto de dependências), não como variável local recriada a cada `build`. É o mesmo `GetRankingUseCase` da aba de Ranking.
- Crie o `ProfileController` **fora do `build`** (por exemplo no `initState` do contêiner). Criá-lo dentro de `build` faz um controller novo e uma requisição nova a cada redesenho.
- Um `401` em qualquer chamada dispara `ApiClient.onUnauthorized`, que já executa o fluxo de logout. Ao sair, remova todas as abas e qualquer controller de partida ativo.

---

## Passo 5: verificar

1. Abra o Profile após o login: apelido e ID aparecem **mesmo se a rede falhar**.
2. Confira pontuação e posição contra `GET /users/ranking`.
3. Desligue a API e puxe para atualizar: a mensagem de erro aparece, **os dados anteriores continuam visíveis** e **Tentar novamente** funciona.
4. Toque em **Sair** e reabra o app: o login deve aparecer.
5. Toque duas vezes rápido em atualizar: só uma requisição deve sair (proteção do passo 2.3, item 1).
6. Se seu usuário não estiver na lista do ranking, veja "Posição indisponível" e não "último lugar".

## Armadilhas comuns

- Procurar o usuário por **apelido** ou por `GamePlayer.id` em vez de `session.user.id`.
- Chamar `refresh` dentro do `build` (loop infinito de requisições).
- Perder os dados anteriores ao entrar em `failure` (por isso os métodos do state copiam os campos).
- Criar o `ApiClient` ou o repositório dentro da página.
- Esquecer `dispose` do controller.

## Exercícios

1. Escreva um teste do `ProfileController` com um `GetRankingUseCase` falso e verifique a sequência `loading`, depois `success`.
2. Teste o caso de usuário ausente do ranking: `position` deve ser `null` e `points` deve vir da sessão.
3. Mostre "Servidor indisponível" quando a exceção for `NetworkException`, sem mudar o controller.
4. Destaque visualmente o usuário logado na aba de [Ranking](../ranking/guia.md) usando o mesmo critério de ID.

Veja [Ranking](../ranking/guia.md) para o mesmo endpoint e a [dock](../../../guia_dock.md) para adicionar a aba.
