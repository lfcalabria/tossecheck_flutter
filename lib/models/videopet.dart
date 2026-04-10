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

  /// ✅ IMPORTANTE:
  /// - Emulador Android: 10.0.2.2
  /// - Backend agora está versionado: /api/v1
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

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

  /// ✅ SYNC USUÁRIO
  /// Backend: POST /api/v1/sync/usuario/
  /// Retorna: { "uuid": "..." }
  Future<SyncResult> sincronizarUsuarioLocal(Usuario usuarioLocal) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/sync/usuario/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': usuarioLocal.nome,
          'cpf': usuarioLocal.cpf,
          'telefone': usuarioLocal.telefone,
        }),
      );

      final responseBody = _decodeBodySafe(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final uuid = responseBody['uuid']?.toString();

        if (uuid == null || uuid.isEmpty) {
          return SyncResult(
            sucesso: false,
            conflito: false,
            mensagem: 'Backend não retornou UUID do usuário.',
          );
        }

        usuarioLocal.uuid = uuid;
        usuarioLocal.sincronizado = true;

        // flags locais (backend pode controlar depois)
        usuarioLocal.bloqueado = false;
        usuarioLocal.liberado = true;

        await dbHelper.updateUsuario(usuarioLocal);

        // ✅ IMPORTANTE:
        // Seu backend sync_usuario não devolve lista de pets.
        // Portanto removemos a tentativa de salvar pets aqui.

        return SyncResult(
          sucesso: true,
          conflito: false,
          uuid: usuarioLocal.uuid,
          mensagem: 'Sincronização do usuário concluída com sucesso.',
        );
      }

      // Seu backend normalmente não retorna 409.
      // Se houver conflito por CPF (unique), pode vir como 400 com mensagem.
      final msgErro = responseBody['erro']?.toString()
          ?? responseBody['message']?.toString()
          ?? 'Erro desconhecido ao sincronizar usuário.';

      // Heurística simples para conflito por CPF (se o backend enviar texto)
      final isConflitoCpf = msgErro.toLowerCase().contains('cpf') &&
          (msgErro.toLowerCase().contains('existe') ||
              msgErro.toLowerCase().contains('unique') ||
              msgErro.toLowerCase().contains('duplic'));

      if (isConflitoCpf) {
        usuarioLocal.sincronizado = false;
        usuarioLocal.bloqueado = true;
        usuarioLocal.liberado = false;
        await dbHelper.updateUsuario(usuarioLocal);

        return SyncResult(
          sucesso: false,
          conflito: true,
          uuid: responseBody['uuid']?.toString(),
          mensagem: msgErro,
        );
      }

      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: msgErro,
      );
    } catch (e) {
      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: 'Falha ao sincronizar usuário: $e',
      );
    }
  }

  /// ✅ SINCRONIZA TUDO (usuário -> pets -> vídeos)
  Future<void> sincronizarGeral() async {
    if (_isSyncing) return;
    if (!await hasInternet()) return;

    _isSyncing = true;
    bool dadosAtualizados = false;
    final dbHelper = DatabaseHelper.instance;

    try {
      final usuarioLocal = await dbHelper.getUsuario();
      if (usuarioLocal == null) return;

      // 1) Sync usuário
      if (!usuarioLocal.sincronizado) {
        final resultado = await sincronizarUsuarioLocal(usuarioLocal);

        if (resultado.conflito) {
          // Se o usuário estiver bloqueado/conflito, não prossegue.
          return;
        }

        if (resultado.sucesso) {
          dadosAtualizados = true;
        }
      }

      final usuarioAtualizado = await dbHelper.getUsuario();
      if (usuarioAtualizado == null || usuarioAtualizado.uuid == null) return;

      // 2) Sync pets pendentes
      final petsPendentesMaps = await dbHelper.getPendentes('pets');
      for (final petMap in petsPendentesMaps) {
        final pet = Pet.fromMap(petMap);

        final res = await http.post(
          Uri.parse('$baseUrl/sync/pet/'),
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
        } else {
          final msg = body['erro']?.toString() ?? 'Erro ao sincronizar pet.';
          print('⚠️ [SYNC PET] ${res.statusCode} - $msg');
        }
      }

      // 3) Sync vídeos pendentes
      final videosPendentesMaps = await dbHelper.getPendentes('videos');
      for (final vidMap in videosPendentesMaps) {
        final video = VideoPet.fromMap(vidMap);

        // garante petUuid (para enviar ao backend)
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

        if (video.petUuid == null || video.petUuid!.isEmpty) continue;

        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/upload/video/'),
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
          } else {
            final msg = body['erro']?.toString() ?? 'Erro ao enviar vídeo.';
            print('⚠️ [SYNC VÍDEO] ${response.statusCode} - $msg');
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
