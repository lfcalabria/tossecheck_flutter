import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../database/database_helper.dart';
import '../models/pet.dart';
import '../services/api_service.dart';

class CadastroPetScreen extends StatefulWidget {
  const CadastroPetScreen({super.key});

  @override
  State<CadastroPetScreen> createState() => _CadastroPetScreenState();
}

class _CadastroPetScreenState extends State<CadastroPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _racaController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();

  String? _tipoSelecionado; // "Cachorro" | "Gato"
  String? _sexoSelecionado; // "Macho" | "Fêmea"
  String? _fotoPath;
  bool _salvando = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _capturarFoto(ImageSource source) async {
    final XFile? foto = await _picker.pickImage(source: source, imageQuality: 80);
    if (foto != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = path.join(appDir.path, fileName);
      await File(foto.path).copy(newPath);
      setState(() => _fotoPath = newPath);
    }
  }

  void _mostrarOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _capturarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _capturarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final db = DatabaseHelper.instance;
      final usuario = await db.getUsuario();

      if (usuario == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastre o responsável antes de cadastrar o pet.')),
        );
        setState(() => _salvando = false);
        return;
      }

      // Parse seguro (mesmo com validator, evita crash)
      final idade = int.tryParse(_idadeController.text.trim());
      final peso = double.tryParse(_pesoController.text.trim().replaceAll(',', '.'));
      final altura = double.tryParse(_alturaController.text.trim().replaceAll(',', '.'));

      final pet = Pet(
        usuarioUuid: usuario.uuid, // pode ser null antes do sync (ok no SQLite)
        nome: _nomeController.text.trim(),
        tipo: _tipoSelecionado!,     // ✅ "Cachorro" | "Gato"
        sexo: _sexoSelecionado,      // ✅ "Macho" | "Fêmea"
        raca: _racaController.text.trim().isEmpty ? null : _racaController.text.trim(),
        idade: idade,
        peso: peso,
        altura: altura,
        fotoPath: _fotoPath,
        dataCadastro: DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        sincronizado: false,
      );

      await db.insertPet(pet);

      // tenta sincronizar (se tiver internet)
      await ApiService().sincronizarGeral();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _racaController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Pet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _mostrarOpcoesFoto,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _fotoPath != null ? FileImage(File(_fotoPath!)) : null,
                  child: _fotoPath == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Pet',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                initialValue: _tipoSelecionado,
                items: const [
                  DropdownMenuItem(value: 'Cachorro', child: Text('Cachorro')),
                  DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                ],
                onChanged: (v) => setState(() => _tipoSelecionado = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Sexo',
                  border: OutlineInputBorder(),
                ),
                initialValue: _sexoSelecionado,
                items: const [
                  DropdownMenuItem(value: 'Macho', child: Text('Macho')),
                  DropdownMenuItem(value: 'Fêmea', child: Text('Fêmea')),
                ],
                onChanged: (v) => setState(() => _sexoSelecionado = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _racaController,
                decoration: const InputDecoration(
                  labelText: 'Raça',
                  border: OutlineInputBorder(),
                ),
                // se quiser manter obrigatório, deixe como está:
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      decoration: const InputDecoration(
                        labelText: 'Idade (anos)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pesoController,
                      decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _alturaController,
                      decoration: const InputDecoration(
                        labelText: 'Altura (cm)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal,
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Salvar Pet',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}