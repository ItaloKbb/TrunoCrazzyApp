import 'package:flutter/material.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/login_credentials.dart';
import '../controllers/login_controller.dart';
import '../state/login_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
    required this.onLoggedIn,
  });

  final LoginController controller;
  final void Function(AuthSession session) onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _code = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _nickname.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onChange() {
    final state = widget.controller.state;
    if (state.status == LoginStatus.success && state.session != null) {
      widget.onLoggedIn(state.session!);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.controller.login(_nickname.text, _code.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final state = widget.controller.state;
                  return Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Truno Crazzy',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'O primeiro acesso cria a conta. Nos seguintes, use o mesmo código.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nickname,
                          enabled: !state.isLoading,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          maxLength: LoginCredentials.maxNicknameLength,
                          decoration: const InputDecoration(
                            labelText: 'Apelido',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Informe seu apelido'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _code,
                          enabled: !state.isLoading,
                          obscureText: _obscure,
                          maxLength: LoginCredentials.maxCodeLength,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Código',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Mostrar código' : 'Ocultar código',
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            final n = v?.length ?? 0;
                            if (n < LoginCredentials.minCodeLength) {
                              return 'O código deve ter ao menos ${LoginCredentials.minCodeLength} caracteres';
                            }
                            return null;
                          },
                        ),
                        if (state.status == LoginStatus.failure) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.error?.message ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: state.isLoading ? null : _submit,
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
