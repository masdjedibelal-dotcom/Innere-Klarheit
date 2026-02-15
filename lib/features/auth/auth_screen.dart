import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/profile_state.dart';
import '../../state/user_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Profil erstellen' : 'Anmelden';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRegister
                    ? 'Erstelle dein Profil mit E-Mail und Passwort.'
                    : 'Melde dich mit deinem Profil an.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.75),
                    ),
              ),
              const SizedBox(height: 16),
              if (_isRegister) ...[
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Passwort',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading
                    ? 'Bitte warten…'
                    : _isRegister
                        ? 'Registrieren'
                        : 'Anmelden'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister
                    ? 'Schon ein Konto? Anmelden'
                    : 'Noch kein Konto? Registrieren'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Bitte eine gültige E-Mail eingeben.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Passwort muss mindestens 6 Zeichen haben.');
      return;
    }
    if (_isRegister && name.isEmpty) {
      setState(() => _error = 'Bitte einen Namen eingeben.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final currentEmail = client.auth.currentUser?.email ?? '';
      if (currentEmail.isEmpty) {
        await client.auth.signOut();
      }

      if (_isRegister) {
        final result =
            await client.auth.signUp(email: email, password: password);
        if (result.session == null) {
          setState(() {
            _error =
                'Bitte bestätige deine E-Mail. Danach kannst du dich anmelden.';
            _loading = false;
          });
          return;
        }
        final profile = ref.read(userProfileRepoProvider);
        await profile.getOrCreate();
        await profile.updateDisplayName(name);
        ref.read(userStateProvider.notifier).setLoggedIn(true);
        ref.read(userStateProvider.notifier).setProfileName(name);
      } else {
        final result = await client.auth
            .signInWithPassword(email: email, password: password);
        if (result.session == null) {
          throw const AuthException('Anmeldung fehlgeschlagen.');
        }
        final profile = ref.read(userProfileRepoProvider);
        final fetched = await profile.getOrCreate();
        if (fetched.displayName.isNotEmpty) {
          ref
              .read(userStateProvider.notifier)
              .setProfileName(fetched.displayName);
        }
        ref.read(userStateProvider.notifier).setLoggedIn(true);
      }

      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      context.go('/profil');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Etwas ist schiefgelaufen. Bitte erneut versuchen.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}











