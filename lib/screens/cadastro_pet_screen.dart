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
  _CadastroPetScreenState createState() => _CadastroPetScreenState();
}

class _CadastroPetScreenState extends State<CadastroPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _racaController = TextEditingController();
  final _idadeController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  
  String? _tipoSelecionado;
  String? _sexoSelecionado;
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
              leading: const Icon(Icons.camera_alt), title: const Text('Câmera'),
              onTap: () { Navigator.pop(context); _capturarFoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo), title: const Text('Galeria'),
              onTap: () { Navigator.pop(context); _capturarFoto(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSelecionado == null || _sexoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione Tipo e Sexo.')));
      return;
    }

    setState(() => _salvando = true);
    final usuario = await DatabaseHelper.instance.getUsuario();

    final pet = Pet(
      usuarioUuid: usuario?.uuid,
      nome: _nomeController.text.trim(),
      tipo: _tipoSelecionado!,
      sexo: _sexoSelecionado!,
      raca: _racaController.text.trim(),
      idade: int.parse(_idadeController.text),
      peso: double.parse(_pesoController.text.replaceAll(',', '.')),
      altura: double.parse(_alturaController.text.replaceAll(',', '.')),
      fotoPath: _fotoPath,
      dataCadastro: DateTime.now(),
      dataUltimaAtualizacao: DateTime.now(),
      sincronizado: false,
    );

    await DatabaseHelper.instance.insertPet(pet);
    await ApiService().sincronizarGeral();

    setState(() => _salvando = false);
    if (mounted) Navigator.pop(context);
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
                  child: _fotoPath == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Pet', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                initialValue: _tipoSelecionado,
                items: const [
                  DropdownMenuItem(value: 'cachorro', child: Text('Cachorro')),
                  DropdownMenuItem(value: 'gato', child: Text('Gato')),
                ],
                onChanged: (v) => setState(() => _tipoSelecionado = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Sexo', border: OutlineInputBorder()),
                initialValue: _sexoSelecionado,
                items: const [
                  DropdownMenuItem(value: 'masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'feminino', child: Text('Feminino')),
                ],
                onChanged: (v) => setState(() => _sexoSelecionado = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _racaController,
                decoration: const InputDecoration(labelText: 'Raça', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      decoration: const InputDecoration(labelText: 'Idade (anos)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pesoController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _alturaController,
                      decoration: const InputDecoration(labelText: 'Altura (cm)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.teal),
                child: _salvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar Pet', style: TextStyle(color: Colors.white, fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
