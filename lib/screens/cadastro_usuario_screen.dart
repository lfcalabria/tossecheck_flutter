import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'lista_pets_screen.dart';
 
class CadastroUsuarioScreen extends StatefulWidget {
  const CadastroUsuarioScreen({Key? key}) : super(key: key);

  @override
  _CadastroUsuarioScreenState createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _telefoneController = TextEditingController();
  bool _salvando = false;

  // 👉 FUNÇÃO INTELIGENTE: Formatação perfeita para nomes brasileiros
  String _formatarNome(String nome) {
    if (nome.trim().isEmpty) return '';
    
    // O RegExp(r'\s+') garante que se o usuário der dois espaços sem querer, o código não quebra
    return nome.trim().split(RegExp(r'\s+')).map((palavra) {
      if (palavra.isEmpty) return '';
      
      // Lista exata de conectivos que devem ficar sempre minúsculos
      if (['de', 'da', 'das', 'do', 'dos', 'e'].contains(palavra.toLowerCase())) {
        return palavra.toLowerCase();
      }
      
      // As demais palavras ganham a primeira letra maiúscula
      return palavra[0].toUpperCase() + palavra.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    // Aplica a formatação no nome antes de criar o objeto
    String nomeFormatado = _formatarNome(_nomeController.text);

    final usuario = Usuario(
      nome: nomeFormatado,
      cpf: _cpfController.text.replaceAll(RegExp(r'[^\d]'), ''),
      telefone: _telefoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
      dataCadastro: DateTime.now(),
      dataUltimaAtualizacao: DateTime.now(),
      sincronizado: false,
    );

    // Salva localmente
    await DatabaseHelper.instance.insertUsuario(usuario);

    // Tenta sincronizar imediatamente se houver internet
    await ApiService().sincronizarGeral();

    setState(() => _salvando = false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ListaPetsScreen()),
      );
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
                
                // CAMPO NOME (Com TextCapitalization.words)
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v!.trim().isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 16),

                // CAMPO CPF (Max 11 e apenas números)
                TextFormField(
                  controller: _cpfController,
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    counterText: '', // Remove o contador visual (0/11)
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 11, // Trava a digitação em 11 caracteres
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe seu CPF';
                    if (v.length != 11) return 'O CPF deve ter exatamente 11 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // CAMPO TELEFONE (Max 11 e apenas números)
                TextFormField(
                  controller: _telefoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefone (Celular com DDD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    counterText: '', // Remove o contador visual (0/11)
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 11, // Trava a digitação em 11 caracteres (DDD + 9)
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe seu telefone';
                    if (v.length != 11) return 'Telefone deve ter 11 dígitos (DDD+9)';
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