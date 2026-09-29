# Tutorial: a camada de Presentation (feature Auth)

Este tutorial explica a camada de **presentation** usando o fluxo de login real do app. Todo o código mostrado existe no projeto.

## 1. Onde a presentation se encaixa

O app é dividido em três camadas por feature:

```text
presentation  ->  domain  <-  data
(telas)          (regras)     (API, disco)
```

- **domain**: o que o app faz. Entidades, interfaces de repositório e casos de uso. Não conhece Flutter nem HTTP.
- **data**: como falar com o mundo externo (API, `shared_preferences`). Implementa as interfaces do domain.
- **presentation**: o que o usuário vê e toca. Telas, estado e controllers.

A presentation **depende do domain**, nunca da data. Ela chama casos de uso e não sabe se os dados vêm de HTTP ou de um arquivo.

O caminho completo de um clique em "Entrar":

```text
LoginPage -> LoginController -> LoginUseCase -> AuthRepository (interface)
                                                     |
                               AuthRepositoryImpl -> ApiClient -> API
```

## 2. Estrutura de pastas

```text
lib/features/auth/presentation/
  state/        login_state.dart        <- o "retrato" da tela em cada momento
  controllers/  login_controller.dart   <- a lógica da tela
  pages/        login_page.dart         <- os widgets
```

Cada pasta tem uma responsabilidade. Vamos por ordem de dependência: estado, controller e página.

## 3. State: descrever a tela como dados

Arquivo: `state/login_state.dart`

```dart
enum LoginStatus { idle, loading, success, failure }

final class LoginState {
  final LoginStatus status;
  final AuthSession? session;
  final AppException? error;

  const LoginState._({required this.status, this.session, this.error});

  const LoginState.idle() : this._(status: LoginStatus.idle);
  const LoginState.loading() : this._(status: LoginStatus.loading);
  const LoginState.success(AuthSession session)
      : this._(status: LoginStatus.success, session: session);
  const LoginState.failure(AppException error)
      : this._(status: LoginStatus.failure, error: error);

  bool get isLoading => status == LoginStatus.loading;
}
```

**Responsabilidade:** representar tudo o que a tela precisa saber, sem lógica de negócio.

**Ideia central:** a UI é uma função do estado (`UI = f(state)`). Em vez de sair mudando widgets, o controller troca o estado e a tela se redesenha.

Os quatro estados possíveis:

| Estado | Quando | O que a tela mostra |
|---|---|---|
| `idle` | tela recém aberta | formulário vazio |
| `loading` | esperando a API | botão desabilitado com spinner |
| `success` | login aceito | (navega para a home) |
| `failure` | erro | mensagem de erro em vermelho |

**Por que construtores nomeados?** `LoginState.failure(erro)` só aceita criar uma falha com erro. Isso impede estados impossíveis, como `success` sem sessão.

**Por que `const LoginState._`?** O construtor privado força o uso dos nomeados. Ninguém de fora cria um estado inconsistente.

### ViewState genérico

Em `lib/core/ui/state/view_State.dart` existe uma versão genérica (`ViewState<T>` com `ViewStatus`) para as próximas telas (ranking, catálogo). O `LoginState` é a versão específica: aqui a tela de login tem regras próprias.

## 4. Controller: a lógica da tela

Arquivo: `controllers/login_controller.dart`

```dart
class LoginController extends ChangeNotifier {
  final LoginUseCase _login;

  LoginController(this._login);

  LoginState _state = const LoginState.idle();
  LoginState get state => _state;

  Future<void> login(String nickname, String code) async {
    if (_state.isLoading) return;                       // 1
    final credentials = LoginCredentials(nickname: nickname, code: code);
    if (!credentials.isValid) {                         // 2
      _emit(const LoginState.failure(BadRequestException(message: '...')));
      return;
    }
    _emit(const LoginState.loading());                  // 3
    try {
      _emit(LoginState.success(await _login(credentials)));   // 4
    } on AppException catch (e) {
      _emit(LoginState.failure(e));                     // 5
    } catch (e) {
      _emit(LoginState.failure(UnexpectedException(cause: e)));
    }
  }

  void _emit(LoginState state) {
    _state = state;
    notifyListeners();                                  // 6
  }
}
```

**Responsabilidade:** receber as ações da tela, chamar o caso de uso e transformar o resultado em estado.

Passo a passo do método `login`:

1. **Evita duplo clique:** se já está carregando, ignora.
2. **Valida antes de chamar a rede:** `LoginCredentials.isValid` (regras do domain) evita uma requisição desnecessária.
3. **Emite `loading`** para a tela mostrar o spinner.
4. **Chama o caso de uso** e, se deu certo, emite `success` com a sessão.
5. **Traduz exceções em estado.** Erros da API (`AppException`, como 401 ou 409) viram `failure` com a mensagem da API. Qualquer outro erro vira `UnexpectedException`.
6. **`notifyListeners()`** avisa quem está ouvindo (a tela) que o estado mudou.

**O que o controller NÃO faz:**
- Não cria widgets nem usa `BuildContext`.
- Não faz HTTP.
- Não navega: só emite o estado. Quem decide navegar é a tela ou o `main`.

Isso o torna fácil de testar: basta criar o controller com um caso de uso falso e verificar a sequência de estados (`loading`, depois `success` ou `failure`), sem abrir nenhuma tela.

**`ChangeNotifier`** é o mecanismo nativo do Flutter para "objeto observável", sem pacote extra. Poderia ser Provider, Riverpod ou BLoC. A ideia de estado, controller e tela seria a mesma.

## 5. Page: os widgets

Arquivo: `pages/login_page.dart`

**Responsabilidade:** desenhar o estado atual e repassar as ações do usuário ao controller.

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller, required this.onLoggedIn});

  final LoginController controller;
  final void Function(AuthSession session) onLoggedIn;
  ...
}
```

A página recebe **de fora** o controller e o `onLoggedIn`. Ela não cria dependências nem sabe para onde ir depois do login. Isso se chama *injeção de dependência* e deixa a tela reutilizável e testável.

### 5.1 Ouvir o estado com `ListenableBuilder`

```dart
ListenableBuilder(
  listenable: widget.controller,
  builder: (context, _) {
    final state = widget.controller.state;
    return Form( ... );
  },
)
```

Sempre que o controller chama `notifyListeners()`, o `builder` roda de novo e o formulário é redesenhado com o estado novo. Só essa parte da tela é reconstruída.

### 5.2 Desenhar cada estado

```dart
TextFormField(
  controller: _nickname,
  enabled: !state.isLoading,          // desabilita durante a requisição
  ...
)

if (state.status == LoginStatus.failure) ...[
  Text(state.error?.message ?? '',
       style: TextStyle(color: Theme.of(context).colorScheme.error)),
],

FilledButton(
  onPressed: state.isLoading ? null : _submit,   // null = botão desabilitado
  child: state.isLoading
      ? const CircularProgressIndicator(strokeWidth: 2)
      : const Text('Entrar'),
)
```

Repare que não existe `setState` para loading ou erro. A tela apenas **lê** o estado e o controller é o único que o altera.

### 5.3 Validação de formulário x regra de negócio

```dart
validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu apelido' : null,
```

- O `validator` do formulário dá **feedback imediato** no campo, sem rede.
- A regra oficial (`LoginCredentials.isValid`) está no domain e é reforçada no controller.

Os limites usam as constantes do domain (`LoginCredentials.maxNicknameLength` etc.), sem números repetidos na tela.

### 5.4 Reagir ao sucesso

```dart
@override
void initState() {
  super.initState();
  widget.controller.addListener(_onChange);
}

void _onChange() {
  final state = widget.controller.state;
  if (state.status == LoginStatus.success && state.session != null) {
    widget.onLoggedIn(state.session!);
  }
}

@override
void dispose() {
  widget.controller.removeListener(_onChange);
  _nickname.dispose();
  _code.dispose();
  super.dispose();
}
```

- Desenhar (`builder`) e **reagir** (navegar) são coisas diferentes. O `addListener` cuida da reação.
- `dispose` remove o listener e libera os `TextEditingController`. Sem isso, há vazamento de memória.

## 6. Onde tudo é montado: `main.dart`

A presentation não sabe qual implementação usar. Quem sabe é o `main.dart` (o *composition root*):

```dart
_api = ApiClient(
  tokenProvider: () async => (await _sessions.getCurrentSession())?.token,
  onUnauthorized: _logout,
);
_login = LoginUseCase(AuthRepositoryImpl(_api), _sessions);
...
home = LoginPage(
  controller: _loginController!,
  onLoggedIn: (session) => setState(() => _session = session),
);
```

Ele cria as implementações (data), monta o caso de uso (domain), entrega o controller à página (presentation) e decide a navegação: se há sessão, mostra a `HomePage`; senão, o login. Ao abrir o app ele lê a sessão salva (`GetCurrentSessionUseCase`), então o usuário não precisa logar de novo.

Um 401 em qualquer chamada dispara `onUnauthorized`, que limpa a sessão e volta ao login.

## 7. O fluxo completo, passo a passo

1. O usuário digita apelido e código e toca em **Entrar**.
2. `LoginPage._submit` valida o formulário e chama `controller.login(...)`.
3. O controller emite `loading` e a tela mostra o spinner.
4. O `LoginUseCase` chama `AuthRepositoryImpl`, que faz `POST /auth/sessions` pelo `ApiClient` e salva a sessão.
5. **Sucesso:** o controller emite `success`, o listener chama `onLoggedIn` e o `main` mostra a `HomePage`.
6. **Erro:** o controller emite `failure` e a tela mostra `state.error.message` (a mensagem devolvida pela API).

## 8. Regras de ouro da presentation

| Faça | Não faça |
|---|---|
| Chamar **casos de uso** | Chamar `ApiClient`, `http` ou `shared_preferences` |
| Representar a tela como **estado** | Guardar regra de negócio em widgets |
| Traduzir exceções em estado de erro | Deixar exceção estourar na tela |
| Receber dependências por parâmetro | Criar repositórios dentro da página |
| Limpar listeners e controllers no `dispose` | Esquecer `dispose` |
| Mostrar a mensagem da API | Inventar textos de erro por status HTTP |

## 9. Como criar uma nova tela (receita)

Exemplo: tela de ranking.

1. **State:** `RankingState` (ou `ViewState<List<RankingEntry>>`) com carregando, sucesso e erro.
2. **Controller:** `RankingController extends ChangeNotifier`, que recebe `GetRankingUseCase`, tem `load()` e emite o estado.
3. **Page:** `RankingPage` recebe o controller, chama `load()` no `initState` e desenha o estado com `ListenableBuilder`.
4. **main.dart:** cria `RankingRepositoryImpl`, `GetRankingUseCase` e o controller, e entrega à página.

O domain e a data desse fluxo já existem. Só falta a presentation.

## 10. Exercícios para a turma

1. Adicione um botão "mostrar/ocultar código" (já existe: descubra onde o `setState` é usado e por que ele é aceitável ali).
2. Crie um teste do `LoginController` com um `LoginUseCase` falso e verifique a sequência `loading`, depois `failure`.
3. Faça a tela mostrar "Servidor indisponível" quando a exceção for `NetworkException`, sem mudar o controller.
4. Crie a `RankingPage` seguindo a receita da seção 9.
5. Discussão: por que o controller não chama `Navigator.push`? O que ficaria mais difícil de testar?
