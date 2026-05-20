import 'package:flutter/material.dart';
import 'screens/liquid_ether_demo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Ether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9d5cfc),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LiquidEtherDemo(),
    );
  }
}
