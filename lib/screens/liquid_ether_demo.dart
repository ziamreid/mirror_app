import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../widgets/liquid_ether.dart';

class LiquidEtherDemo extends StatefulWidget {
  const LiquidEtherDemo({super.key});

  @override
  State<LiquidEtherDemo> createState() => _LiquidEtherDemoState();
}

class _LiquidEtherDemoState extends State<LiquidEtherDemo> with SingleTickerProviderStateMixin {
  double _flowSpeed = 0.25;
  double _turbulence = 1.0;
  double _glowIntensity = 1.5;
  double _emotionalState = 1.0;  // 0=fog, 1=processing, 2=clarity, 3=conviction
  bool _hasTouched = false;

  // FPS Tracking
  late final Ticker _fpsTicker;
  int _frameCount = 0;
  double _fps = 60.0;
  Duration _lastFpsTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Run a lightweight ticker to sample screen rendering frames and calculate FPS
    _fpsTicker = createTicker((elapsed) {
      _frameCount++;
      if (_lastFpsTime == Duration.zero) {
        _lastFpsTime = elapsed;
        return;
      }
      final elapsedMs = (elapsed - _lastFpsTime).inMilliseconds;
      if (elapsedMs >= 500) {
        if (mounted) {
          setState(() {
            _fps = (_frameCount * 1000.0) / elapsedMs;
          });
        }
        _frameCount = 0;
        _lastFpsTime = elapsed;
      }
    });
    _fpsTicker.start();
  }

  @override
  void dispose() {
    _fpsTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060312),
      // Allow fluid background to flow completely edge-to-edge behind app bars/notch
      extendBodyBehindAppBar: true,
      body: Listener(
        onPointerDown: (_) {
          if (!_hasTouched) {
            setState(() {
              _hasTouched = true;
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main Fluid Simulation Background
            LiquidEther(
              flowSpeed: _flowSpeed,
              turbulence: _turbulence,
              glowIntensity: _glowIntensity,
              emotionalState: _emotionalState,
              interactable: true,
            ),

            // Top Status Overlay (Safe Area for Notch)
            Positioned(
              top: 54.0,
              left: 20.0,
              right: 20.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ETHER.IO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                  // Real-time FPS Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _fps >= 55 ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_fps >= 55 ? Colors.greenAccent : Colors.orangeAccent)
                                    .withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          '${_fps.toStringAsFixed(0)} FPS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Center Floating Glassmorphic Card
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      width: 340,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 40.0,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Custom Glowing Icon
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6312A3).withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF9d5cfc).withOpacity(0.35),
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.spa_outlined,
                              color: Color(0xFFdcb5ff),
                              size: 28.0,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          const Text(
                            'Liquid Ether',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            'Navier-Stokes Fluid Field',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24.0),
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          const SizedBox(height: 20.0),
                          Text(
                            'Multi-touch interaction is fully supported. Tweak the simulation settings below in real-time.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13.0,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Instruction Prompt (Fades Out After First Touch)
            Positioned(
              top: 120.0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _hasTouched ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      color: Colors.white54,
                      size: 24.0,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'TOUCH & SWIRL SCREEN',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls Glass Panel
            Positioned(
              bottom: 24.0,
              left: 16.0,
              right: 16.0,
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSliderRow(
                            label: 'Flow Speed',
                            value: _flowSpeed,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (val) => setState(() => _flowSpeed = val),
                            displayValue: _flowSpeed.toStringAsFixed(2),
                          ),
                          const SizedBox(height: 14.0),
                          _buildSliderRow(
                            label: 'Turbulence',
                            value: _turbulence,
                            min: 0.5,
                            max: 3.0,
                            onChanged: (val) => setState(() => _turbulence = val),
                            displayValue: _turbulence.toStringAsFixed(2),
                          ),
                          const SizedBox(height: 14.0),
                          _buildSliderRow(
                            label: 'Glow Intensity',
                            value: _glowIntensity,
                            min: 0.5,
                            max: 2.0,
                            onChanged: (val) => setState(() => _glowIntensity = val),
                            displayValue: _glowIntensity.toStringAsFixed(2),
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
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF9d5cfc),
              inactiveTrackColor: Colors.white.withOpacity(0.15),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF9d5cfc).withOpacity(0.2),
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            displayValue,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
