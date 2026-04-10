import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../models/pet.dart';
import '../models/videopet.dart';

class SyncResult {
  final bool sucesso;
  final bool conflito;
  final String? uuid;
  final String? mensagem;

  SyncResult({
    required this.sucesso,
    required this.conflito,
    this.uuid,
    this.mensagem,
  });
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'http://10.0.2.2:8000';

  bool _isSyncing = false;
  Function? onSyncComplete;

  void iniciarListenerDeConexao() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        sincronizarGeral();
      }
    });
  }

  Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
  }

  Map<String, dynamic> _decodeBodySafe(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<SyncResult> sincronizarUsuarioLocal(Usuario usuarioLocal) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/sync/usuario'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': usuarioLocal.nome,
          'cpf': usuarioLocal.cpf,
          'telefone': usuarioLocal.telefone,
        }),
      );

      final responseBody = _decodeBodySafe(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        usuarioLocal.uuid = responseBody['uuid']?.toString();
        usuarioLocal.sincronizado = true;
        usuarioLocal.bloqueado = false;
        usuarioLocal.liberado = true;

        await dbHelper.updateUsuario(usuarioLocal);

        final pets = responseBody['pets'];
        if (pets is List) {
          for (final petJson in pets) {
            try {
              final petUuid = petJson['uuid']?.toString();
              if (petUuid == null || petUuid.isEmpty) continue;

              final petExistente = await dbHelper.getPetPorUuid(petUuid);
              if (petExistente == null) {
                final pet = Pet(
                  uuid: petUuid,
                  usuarioUuid: usuarioLocal.uuid,
                  nome: petJson['nome']?.toString() ?? '',
                  tipo: petJson['tipo']?.toString() ?? '',
                  sexo: petJson['sexo']?.toString() ?? '',
                  raca: petJson['raca']?.toString() ?? '',
                  idade: (petJson['idade'] is int)
                      ? petJson['idade'] as int
                      : int.tryParse('${petJson['idade']}') ?? 0,
                  peso: (petJson['peso'] is num)
                      ? (petJson['peso'] as num).toDouble()
                      : 0.0,
                  altura: (petJson['altura'] is num)
                      ? (petJson['altura'] as num).toDouble()
                      : 0.0,
                  dataCadastro: DateTime.now(),
                  dataUltimaAtualizacao: DateTime.now(),
                  sincronizado: true,
                );

                await dbHelper.insertPet(pet);
              }
            } catch (e) {
              print('⚠️ [SYNC USUÁRIO] Erro ao salvar pet local: $e');
            }
          }
        }

        return SyncResult(
          sucesso: true,
          conflito: false,
          uuid: usuarioLocal.uuid,
          mensagem: 'Sincronização concluída com sucesso.',
        );
      }

      if (res.statusCode == 409) {
        usuarioLocal.sincronizado = false;
        usuarioLocal.bloqueado = true;
        usuarioLocal.liberado = false;
        await dbHelper.updateUsuario(usuarioLocal);

        return SyncResult(
          sucesso: false,
          conflito: true,
          uuid: responseBody['uuid']?.toString(),
          mensagem: responseBody['erro']?.toString() ?? 'Conflito de CPF.',
        );
      }

      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: responseBody['erro']?.toString() ??
            responseBody['message']?.toString() ??
            'Erro desconhecido ao sincronizar usuário.',
      );
    } catch (e) {
      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: 'Falha ao sincronizar usuário: $e',
      );
    }
  }

  Future<void> sincronizarGeral() async {
    if (_isSyncing) return;
    if (!await hasInternet()) return;

    _isSyncing = true;
    bool dadosAtualizados = false;
    final dbHelper = DatabaseHelper.instance;

    try {
      final usuarioLocal = await dbHelper.getUsuario();
      if (usuarioLocal == null) {
        return;
      }

      if (!usuarioLocal.sincronizado) {
        final resultado = await sincronizarUsuarioLocal(usuarioLocal);

        if (resultado.conflito) {
          return;
        }

        if (resultado.sucesso) {
          dadosAtualizados = true;
        }
      }

      final usuarioAtualizado = await dbHelper.getUsuario();
      if (usuarioAtualizado == null || usuarioAtualizado.uuid == null) {
        return;
      }

      final petsPendentesMaps = await dbHelper.getPendentes('pets');
      for (final petMap in petsPendentesMaps) {
        final pet = Pet.fromMap(petMap);

        final res = await http.post(
          Uri.parse('$baseUrl/sync/pet'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usuario_uuid': usuarioAtualizado.uuid,
            'nome': pet.nome,
            'tipo': pet.tipo,
            'sexo': pet.sexo,
            'raca': pet.raca,
            'idade': pet.idade,
            'peso': pet.peso,
            'altura': pet.altura,
          }),
        );

        final body = _decodeBodySafe(res.body);

        if (res.statusCode == 200 || res.statusCode == 201) {
          pet.uuid = body['uuid']?.toString();
          pet.usuarioUuid = usuarioAtualizado.uuid;
          pet.sincronizado = true;
          await dbHelper.updatePet(pet);
          dadosAtualizados = true;
        }
      }

      final videosPendentesMaps = await dbHelper.getPendentes('videos');
      for (final vidMap in videosPendentesMaps) {
        final video = VideoPet.fromMap(vidMap);

        if (video.petUuid == null && video.petId != null) {
          final petsList = await dbHelper.getPets();
          try {
            final dono = petsList.firstWhere((p) => p.id == video.petId);
            if (dono.uuid != null) {
              video.petUuid = dono.uuid;
              await dbHelper.updateVideo(video);
            } else {
              continue;
            }
          } catch (_) {
            continue;
          }
        }

        if (video.petUuid == null) continue;

        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/upload/video'),
          );
          request.fields['pet_uuid'] = video.petUuid!;
          request.files.add(
            await http.MultipartFile.fromPath('file', video.caminhoLocal),
          );

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          final body = _decodeBodySafe(response.body);

          if (response.statusCode == 200 || response.statusCode == 201) {
            video.uuid = body['uuid']?.toString();
            video.sincronizado = true;
            await dbHelper.updateVideo(video);
            dadosAtualizados = true;
          }
        } catch (e) {
          print('❌ [SYNC VÍDEOS] Falha ao enviar vídeo: $e');
        }
      }
    } catch (e) {
      print('🚨 [ERRO NETWORK] Falha geral na comunicação: $e');
    } finally {
      _isSyncing = false;

      if (dadosAtualizados && onSyncComplete != null) {
        onSyncComplete!();
      }
    }
  }
}