import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_projects/testweb.dart';
import 'smoke_background.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smoke Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SmokeStage _stage = SmokeStage.fog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090910),
      body: SafeArea(
        child: SmokeBackground(
          stage: _stage,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const FluidBackground(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 360,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Join the flow',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _GlassField(
                              label: 'Name',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 14),
                            _GlassField(
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.85)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
      ),
    );
  }
}