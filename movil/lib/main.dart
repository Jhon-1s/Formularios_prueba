import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormBuilder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3498db),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3498db)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}