import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../utils/cpf_validator.dart';
import 'lista_pets_screen.dart';

class CadastroUsuarioScreen extends StatefulWidget {
  const CadastroUsuarioScreen({super.key});

  @override
  State<CadastroUsuarioScreen> createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  // Formata nomes brasileiros de forma inteligente
  String _formatarNome(String nome) {
    if (nome.trim().isEmpty) return '';

    return nome
        .trim()
        .split(RegExp(r'\s+'))
        .map((palavra) {
          if (palavra.isEmpty) return '';

          if (['de', 'da', 'das', 'do', 'dos', 'e']
              .contains(palavra.toLowerCase())) {
            return palavra.toLowerCase();
          }

          return palavra[0].toUpperCase() + palavra.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final db = DatabaseHelper.instance;

      final nomeFormatado = _formatarNome(_nomeController.text);
      final cpfLimpo = _cpfController.text.replaceAll(RegExp(r'[^\d]'), '');
      final telefoneLimpo =
          _telefoneController.text.replaceAll(RegExp(r'[^\d]'), '');

      // ✅ evita duplicar: se já existir usuário com esse CPF, atualiza
      final usuarioExistente = await db.getUsuarioPorCpf(cpfLimpo);

      Usuario usuario;

      if (usuarioExistente != null) {
        usuario = Usuario(
          id: usuarioExistente.id,
          uuid: usuarioExistente.uuid,
          nome: nomeFormatado,
          cpf: cpfLimpo,
          telefone: telefoneLimpo,
          dataCadastro: usuarioExistente.dataCadastro,
          dataUltimaAtualizacao: DateTime.now(),
          sincronizado: usuarioExistente.sincronizado,
          bloqueado: usuarioExistente.bloqueado,
          liberado: usuarioExistente.liberado,
        );

        await db.updateUsuario(usuario);
      } else {
        usuario = Usuario(
          nome: nomeFormatado,
          cpf: cpfLimpo,
          telefone: telefoneLimpo,
          dataCadastro: DateTime.now(),
          dataUltimaAtualizacao: DateTime.now(),
          sincronizado: false,
          bloqueado: false,
          liberado: true,
        );

        // ✅ pega o id gerado no SQLite e grava no objeto
        final idInserido = await db.insertUsuario(usuario);
        usuario.id = idInserido;
      }

      // tenta sincronizar se houver internet
      final apiService = ApiService();
      final hasInternet = await apiService.hasInternet();

      if (hasInternet) {
        final resultado = await apiService.sincronizarUsuarioLocal(usuario);

        if (resultado.conflito) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  resultado.mensagem ??
                      'Conflito de CPF. O usuário foi bloqueado.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (resultado.sucesso) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar cadastro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.pets, size: 80, color: Colors.teal),
                const SizedBox(height: 16),
                const Text(
                  'Bem-vindo ao TosseCheck!\n\n'
                  'Para utilizar o aplicativo, precisamos do seu cadastro.\n'
                  'Seus dados serão utilizados para personalizar sua experiência '
                  'e sincronizar com nossos servidores.\n\n'
                  'Obrigado por escolher o TosseCheck.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cpfController,
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe seu CPF';
                    }
                    if (!isValidCPF(v)) {
                      return 'CPF inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefone (Celular com DDD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe seu telefone';
                    }
                    if (v.trim().length != 11) {
                      return 'Telefone deve ter 11 dígitos (DDD + 9)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Cadastrar', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}