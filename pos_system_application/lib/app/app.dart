import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:pos_client/features/auth/presentation/views/login_screen.dart';
import 'package:pos_client/features/shell/presentation/shell_screen.dart';

class PosApp extends ConsumerWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    Widget homeScreen;
    if (authState.status == AuthStatus.unauthenticated) {
      homeScreen = const LoginScreen();
    } else {
      homeScreen = const ShellScreen();
    }

    return MaterialApp(
      title: 'Retail POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(authState.status == AuthStatus.unauthenticated
              ? 'login_view'
              : 'shell_view'),
          child: homeScreen,
        ),
      ),
    );
  }
}
