import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'screens/boot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().iniciarListenerDeConexao();
  runApp(const TosseCheckApp());
}

class TosseCheckApp extends StatelessWidget {
  const TosseCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TosseCheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const BootScreen(),
    );
  }
}