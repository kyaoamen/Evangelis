import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_repository.dart';
import '../../state/providers.dart';
import '../common.dart';

/// Passwordless sign-in: email -> 6-digit code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});
  final String? next;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signIn),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const Key('email'),
            controller: _email,
            enabled: !_codeSent,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.email),
          ),
          const SizedBox(height: 16),
          if (!_codeSent)
            FilledButton(
              key: const Key('send-code'),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await repo.sendOtp(_email.text);
                        setState(() => _codeSent = true);
                      }),
              child: Text(l10n.sendCode),
            )
          else ...[
            Text(l10n.codeSentTo(_email.text.trim())),
            if (repo is DemoRepository)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.demoCodeHint, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('code'),
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              decoration: InputDecoration(labelText: l10n.verificationCode),
            ),
            FilledButton(
              key: const Key('verify'),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await repo.verifyOtp(_email.text, _code.text);
                        if (!context.mounted) return;
                        final next = widget.next;
                        next != null && next.startsWith('/') ? context.go(next) : context.go('/');
                      }),
              child: Text(l10n.verify),
            ),
          ],
        ],
      ),
    );
  }
}
