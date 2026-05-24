// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FluidBackground extends StatefulWidget {
  const FluidBackground({super.key});

  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground> {
  static const String _viewType = 'fluid-background-iframe';

  String? _htmlSource;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final htmlSource = await rootBundle.loadString('lib/fluid_touch_simulation.html');
    if (!mounted) {
      return;
    }

    _htmlSource = htmlSource;
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..srcdoc = _htmlSource
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.backgroundColor = 'transparent';
      return iframe;
    });

    setState(() {
      _registered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return const ColoredBox(color: Color(0xFF090910));
    }

    return const SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}