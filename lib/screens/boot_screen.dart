import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../services/api_service.dart';
import 'cadastro_usuario_screen.dart';
import 'lista_pets_screen.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final db = DatabaseHelper.instance;
    final api = ApiService();

    final user = await db.getUsuario();

    if (user == null) {
      _go(const CadastroUsuarioScreen());
      return;
    }

    // se bloqueado localmente: tenta desbloquear via backend
    if (user.bloqueado == true) {
      final online = await api.hasInternet();
      if (online) {
        final liberou = await api.tentarDesbloquearSePossivel(user);
        if (liberou) {
          await api.sincronizarGeral();
          _go(const ListaPetsScreen());
          return;
        }
      }

      _showBlocked();
      return;
    }

    // não bloqueado
    if (await api.hasInternet()) {
      await api.sincronizarGeral();
    }

    _go(const ListaPetsScreen());
  }

  void _go(Widget w) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));
  }

  void _showBlocked() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Acesso bloqueado'),
        content: const Text(
          'Este CPF está bloqueado no sistema.\n\nO aplicativo será encerrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}