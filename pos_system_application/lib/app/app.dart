import 'package:flutter/material.dart';
import 'package:pos_client/app/theme.dart';
import 'package:pos_client/features/shell/presentation/shell_screen.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retail POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ShellScreen(),
    );
  }
}

