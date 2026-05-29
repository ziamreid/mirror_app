import 'package:flutter/material.dart';
import 'package:flutter_projects/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EyeApp());
}

class EyeApp extends StatelessWidget {
  const EyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eye',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: '.SF Pro Rounded',
      ),
      home: const SplashScreen(),
    );
  }
}
