import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';
import 'theme.dart';
import '../state/user_state.dart';

class ClarityApp extends ConsumerStatefulWidget {
  const ClarityApp({super.key});

  @override
  ConsumerState<ClarityApp> createState() => _ClarityAppState();
}

class _ClarityAppState extends ConsumerState<ClarityApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _syncAuthState(Supabase.instance.client.auth.currentUser);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      _syncAuthState(event.session?.user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _syncAuthState(User? user) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasEmailLogin = (user?.email ?? '').isNotEmpty;
      final notifier = ref.read(userStateProvider.notifier);
      notifier.setLoggedIn(hasEmailLogin);
      if (!hasEmailLogin) {
        notifier.setProfileName('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clarity',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
