import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import 'cadastro_pet_screen.dart';
import 'editar_pet_screen.dart';
import 'gravar_video_screen.dart';

class ListaPetsScreen extends StatefulWidget {
  const ListaPetsScreen({Key? key}) : super(key: key);

  @override
  _ListaPetsScreenState createState() => _ListaPetsScreenState();
}

class _ListaPetsScreenState extends State<ListaPetsScreen> {
  Usuario? _usuario;
  List<Pet> _pets = [];
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    
    // Diz para a API atualizar essa tela automaticamente quando terminar o sync em background
    ApiService().onSyncComplete = () {
      if (mounted) _carregarDados();
    };
  }

  @override
  void dispose() {
    // Remove o listener quando a tela for fechada
    ApiService().onSyncComplete = null;
    super.dispose();
  }

  Future<void> _carregarDados() async {
    _usuario = await DatabaseHelper.instance.getUsuario();
    _pets = await DatabaseHelper.instance.getPets();
    if (mounted) setState(() {});
  }

  Future<void> _sincronizarManual() async {
    setState(() => _sincronizando = true);
    await ApiService().sincronizarGeral();
    await _carregarDados();
    setState(() => _sincronizando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronização concluída!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${_usuario?.primeiroNome ?? ""}'),
        actions: [
          if (_sincronizando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _sincronizando ? null : _sincronizarManual,
            tooltip: 'Sincronizar dados',
          ),
        ],
      ),
      body: _pets.isEmpty
          ? const Center(
              child: Text('Nenhum pet cadastrado. Toque no + para adicionar.', 
              style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GravarVideoScreen(pet: pet),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: pet.fotoPath != null ? FileImage(File(pet.fotoPath!)) : null,
                            child: pet.fotoPath == null
                                ? Icon(pet.tipo == 'gato' ? Icons.pets : Icons.pets, size: 35, color: Colors.teal)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pet.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('${pet.tipo} • ${pet.raca}', style: TextStyle(color: Colors.grey.shade700)),
                                if (!pet.sincronizado)
                                  const Text('Pendente de sincronização', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EditarPetScreen(pet: pet),
                              ));
                              _carregarDados();
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroPetScreen()));
          _carregarDados();
        },
      ),
    );
  }
}