import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'services/api_service.dart';
import 'screens/cadastro_usuario_screen.dart';
import 'screens/lista_pets_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 [MAIN] Inicializando o aplicativo TosseCheck...');
  print('🚀 [MAIN] Iniciando o ouvinte de conexão com a internet...');

  ApiService().iniciarListenerDeConexao();

  print('🚀 [MAIN] Forçando a primeira tentativa de sincronização agora...');
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
  State<SplashChecker> createState() => _SplashCheckerState();
}

class _SplashCheckerState extends State<SplashChecker> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    try {
      final user = await DatabaseHelper.instance.getUsuario();

      if (!mounted) return;

      // 1) Se não existe usuário local, ir para cadastro
      if (user == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CadastroUsuarioScreen()),
        );
        return;
      }

      // 2) Se está bloqueado ou não liberado, mostrar conflito e impedir acesso
      final bool bloqueado = user.bloqueado == true;
      final bool liberado = user.liberado == true;
      final bool sincronizado = user.sincronizado == true;

      if (bloqueado || !liberado) {
        _showConflictDialog(
          'Conflito de CPF',
          'Este CPF está com conflito. O acesso ao app foi bloqueado até liberação pelo administrador.',
        );
        return;
      }

      // 3) Se estiver sincronizado e liberado, seguir para pets
      if (sincronizado) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
        );
        return;
      }

      // 4) Se não estiver sincronizado, verificar internet e tentar sincronizar
      final hasInternet = await ApiService().hasInternet();
      if (hasInternet) {
        final resultado = await ApiService().sincronizarUsuarioLocal(user);

        if (!mounted) return;

        if (resultado.conflito == true) {
          _showConflictDialog(
            'Conflito de CPF',
            'Este CPF já está cadastrado para outro usuário. O app foi bloqueado até liberação pelo administrador.',
          );
          return;
        }

        if (resultado.sucesso == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
          );
          return;
        }

        _showConflictDialog(
          'Falha na sincronização',
          resultado.mensagem ?? 'Não foi possível sincronizar o usuário.',
        );
        return;
      }

      // 5) Sem internet: seguir para pets, desde que não esteja bloqueado
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      _showConflictDialog(
        'Erro na inicialização',
        'Não foi possível verificar o usuário local. Detalhe: $e',
      );
    }
  }

  void _showConflictDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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