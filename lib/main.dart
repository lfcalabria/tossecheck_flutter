import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'services/api_service.dart';
import 'screens/cadastro_usuario_screen.dart';
import 'screens/lista_pets_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 [MAIN] Inicializando o aplicativo TosseCheck...');
  print('🚀 [MAIN] Iniciando o ouvinte de conexão com a internet...');
  
  // Inicia o ouvinte que dispara a sincronização IMEDIATAMENTE ao detectar internet
  ApiService().iniciarListenerDeConexao();
  
  print('🚀 [MAIN] Forçando a primeira tentativa de sincronização agora...');
  // Força uma tentativa de sincronização agora mesmo ao abrir o app
  ApiService().sincronizarGeral();

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
      home: const SplashChecker(),
    );
  }
}

class SplashChecker extends StatefulWidget {
  const SplashChecker({super.key});

  @override
  _SplashCheckerState createState() => _SplashCheckerState();
}

class _SplashCheckerState extends State<SplashChecker> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = await DatabaseHelper.instance.getUsuario();
    if (!mounted) return;
    
    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ListaPetsScreen())
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CadastroUsuarioScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.teal),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.teal),
          ],
        ),
      ),
    );
  }
}