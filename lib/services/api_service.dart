import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../models/observacao.dart';

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

  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String hostUrl = 'http://10.0.2.2:8000';

  bool _isSyncing = false;
  Function? onSyncComplete;

  // =========================================================
  // INTERNET
  // =========================================================

  void iniciarListenerDeConexao() {
    Connectivity().onConnectivityChanged.listen((result) {
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

  Uri _statusUriPorCpf(String cpf) {
    return Uri.parse('$baseUrl/tutor/usuario/').replace(queryParameters: {'cpf': cpf});
  }

  Future<Map<String, dynamic>?> _buscarStatusBackendPorCpf(String cpf) async {
    if (!await hasInternet()) return null;
    try {
      final res = await http.get(_statusUriPorCpf(cpf));
      if (res.statusCode != 200) return null;
      final body = _decodeBodySafe(res.body);
      return body.isEmpty ? null : body;
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // ✅ MÉTODO NOVO: chame este método logo após gravar um vídeo
  // =========================================================
  /// Use assim após salvar o vídeo no SQLite:
  ///   await ApiService().sincronizarAposGravarVideo();
  ///
  /// Ele tenta sincronizar imediatamente se houver internet.
  Future<void> sincronizarAposGravarVideo() async {
    if (await hasInternet()) {
      await sincronizarGeral();
    }
  }

  // =========================================================
  // DESBLOQUEIO VIA GET CANÔNICO
  // =========================================================

  Future<bool> tentarDesbloquearSePossivel(Usuario usuarioLocal) async {
    final status = await _buscarStatusBackendPorCpf(usuarioLocal.cpf);
    if (status == null) return false;

    await DatabaseHelper.instance.atualizarUsuarioComDadosDoBackend(
      cpf: usuarioLocal.cpf,
      uuid: status['uuid']?.toString() ?? (usuarioLocal.uuid ?? ''),
      nome: status['nome']?.toString() ?? usuarioLocal.nome,
      telefone: status['telefone']?.toString() ?? usuarioLocal.telefone,
      bloqueado: status['bloqueado'] == true,
      liberado: status['liberado'] == true,
    );

    final atualizado = await DatabaseHelper.instance.getUsuarioPorCpf(usuarioLocal.cpf);
    return atualizado != null && atualizado.liberado == true && atualizado.bloqueado != true;
  }

  // =========================================================
  // SYNC USUÁRIO (POST)
  // =========================================================

  Future<SyncResult> sincronizarUsuarioLocal(Usuario usuarioLocal) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tutor/sync/usuario/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': usuarioLocal.nome,
          'cpf': usuarioLocal.cpf,
          'telefone': usuarioLocal.telefone,
        }),
      );

      final responseBody = _decodeBodySafe(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final uuid = responseBody['uuid']?.toString() ?? (usuarioLocal.uuid ?? '');
        await dbHelper.atualizarUsuarioComDadosDoBackend(
          cpf: usuarioLocal.cpf,
          uuid: uuid,
          nome: usuarioLocal.nome,
          telefone: usuarioLocal.telefone,
          bloqueado: false,
          liberado: true,
        );

        return SyncResult(sucesso: true, conflito: false, uuid: uuid);
      }

      if (res.statusCode == 409) {
        final status = await _buscarStatusBackendPorCpf(usuarioLocal.cpf);
        if (status != null && status['liberado'] == true && status['bloqueado'] != true) {
          await dbHelper.atualizarUsuarioComDadosDoBackend(
            cpf: usuarioLocal.cpf,
            uuid: status['uuid']?.toString() ?? (usuarioLocal.uuid ?? ''),
            nome: status['nome']?.toString() ?? usuarioLocal.nome,
            telefone: status['telefone']?.toString() ?? usuarioLocal.telefone,
            bloqueado: false,
            liberado: true,
          );
          return SyncResult(sucesso: true, conflito: false, uuid: status['uuid']?.toString());
        }

        await dbHelper.marcarUsuarioBloqueado(uuid: usuarioLocal.uuid, id: usuarioLocal.id);
        return SyncResult(
          sucesso: false,
          conflito: true,
          mensagem: responseBody['erro']?.toString() ?? 'Conflito de CPF.',
        );
      }

      if (res.statusCode == 400) {
        return SyncResult(
          sucesso: false,
          conflito: false,
          mensagem: responseBody['erro']?.toString() ?? 'Dados inválidos.',
        );
      }

      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: responseBody['erro']?.toString() ?? 'Erro ao sincronizar usuário.',
      );
    } catch (e) {
      return SyncResult(
        sucesso: false,
        conflito: false,
        mensagem: 'Falha de comunicação: $e',
      );
    }
  }

  // =========================================================
  // BAIXAR PETS + VÍDEOS + OBS (mantém seu código atual)
  // =========================================================

  Future<void> baixarTudoDoBackend() async {
    if (!await hasInternet()) return;

    final db = DatabaseHelper.instance;
    final usuario = await db.getUsuario();
    if (usuario == null || usuario.uuid == null) return;

    final resPets = await http.get(
      Uri.parse('$baseUrl/tutor/pets/?usuario_uuid=${usuario.uuid}'),
    );
    if (resPets.statusCode != 200) return;

    final petsJson = _decodeBodySafe(resPets.body);
    final pets = petsJson['pets'];
    if (pets is! List) return;

    bool mudou = false;

    for (final p in pets) {
      final petUuid = p['uuid']?.toString();
      if (petUuid == null) continue;

      final existente = await db.getPetPorUuid(petUuid);

      final petDoBackend = Pet(
        id: existente?.id,
        uuid: petUuid,
        usuarioUuid: usuario.uuid,
        nome: (p['nome'] ?? '').toString(),
        tipo: (p['tipo'] ?? '').toString(),
        sexo: (p['sexo'] ?? '').toString(),
        raca: (p['raca'] ?? '').toString(),
        idade: (p['idade'] is int) ? p['idade'] : int.tryParse('${p['idade']}') ?? 0,
        peso: (p['peso'] is num) ? (p['peso'] as num).toDouble() : 0.0,
        altura: (p['altura'] is num) ? (p['altura'] as num).toDouble() : 0.0,
        fotoPath: existente?.fotoPath, // preserva foto local
        dataCadastro: existente?.dataCadastro ?? DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        sincronizado: true,
      );

      if (existente == null) {
        await db.insertPet(petDoBackend);
      } else {
        await db.updatePet(petDoBackend);
      }
      mudou = true;

      final resDet = await http.get(Uri.parse('$baseUrl/pets/$petUuid/'));
      if (resDet.statusCode != 200) continue;

      final det = _decodeBodySafe(resDet.body);

      final prontuario = det['prontuario'];
      if (prontuario is List) {
        for (final o in prontuario) {
          final obsUuid = o['uuid']?.toString();
          if (obsUuid == null) continue;

          final obs = Observacao(
            uuid: obsUuid,
            petUuid: petUuid,
            veterinario: (o['veterinario'] ?? '').toString(),
            mensagem: (o['texto'] ?? '').toString(),
            dataCadastro: DateTime.now(),
            dataUltimaAtualizacao: DateTime.now(),
            sincronizado: true,
          );
          await db.upsertObservacaoPorUuid(obs);
          mudou = true;
        }
      }

      final videos = det['videos'];
      if (videos is List) {
        for (final v in videos) {
          final videoUuid = v['uuid']?.toString();
          final url = v['url']?.toString();
          if (videoUuid == null || url == null) continue;

          final jaExiste = await db.getVideoPorUuid(videoUuid);
          if (jaExiste != null) continue;

          final finalUrl = url.startsWith('http') ? url : '$hostUrl$url';
          final caminhoLocal = await _baixarArquivoVideo(finalUrl, videoUuid);

          final video = VideoPet(
            uuid: videoUuid,
            petUuid: petUuid,
            caminhoLocal: caminhoLocal,
            urlServidor: finalUrl,
            dataCadastro: DateTime.now(),
            dataUltimaAtualizacao: DateTime.now(),
            sincronizado: true,
          );

          await db.upsertVideoPorUuid(video);
          mudou = true;
        }
      }
    }

    if (mudou && onSyncComplete != null) {
      onSyncComplete!();
    }
  }

  Future<String> _baixarArquivoVideo(String url, String videoUuid) async {
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${dir.path}/videos');
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    final filePath = '${videosDir.path}/$videoUuid.mp4';
    final file = File(filePath);

    if (await file.exists()) return filePath;

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      await file.writeAsBytes(res.bodyBytes);
    }
    return filePath;
  }

  // =========================================================
  // SYNC GERAL (upload pendentes + download backend)
  // =========================================================

  Future<void> sincronizarGeral() async {
    if (_isSyncing) return;
    if (!await hasInternet()) return;

    _isSyncing = true;
    bool dadosAtualizados = false;
    final dbHelper = DatabaseHelper.instance;

    try {
      var usuario = await dbHelper.getUsuario();
      if (usuario == null) return;

      if (usuario.bloqueado == true || usuario.liberado != true) {
        final liberou = await tentarDesbloquearSePossivel(usuario);
        if (!liberou) return;
        usuario = await dbHelper.getUsuario();
        if (usuario == null) return;
        dadosAtualizados = true;
      }

      if (!usuario.sincronizado) {
        final r = await sincronizarUsuarioLocal(usuario);
        if (r.conflito) return;
        usuario = await dbHelper.getUsuario();
        if (usuario == null) return;
        dadosAtualizados = true;
      }

      // Upload pets pendentes
      final petsPendentes = await dbHelper.getPendentes('pets');
      for (final petMap in petsPendentes) {
        final pet = Pet.fromMap(petMap);

        final res = await http.post(
          Uri.parse('$baseUrl/tutor/sync/pet/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uuid': pet.uuid,
            'usuario_uuid': usuario.uuid,
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
          final newUuid = body['uuid']?.toString();
          if (newUuid != null && newUuid.isNotEmpty) {
            pet.uuid = newUuid;
          }
          pet.usuarioUuid = usuario.uuid;
          pet.sincronizado = true;

          if (pet.id != null) {
            await dbHelper.updatePet(pet);
          } else if (pet.uuid != null && pet.uuid!.isNotEmpty) {
            await dbHelper.updatePetByUuid(pet);
          }

          dadosAtualizados = true;
        }
      }

      // ✅ Upload vídeos pendentes
      final videosPendentes = await dbHelper.getPendentes('videos');
      for (final vidMap in videosPendentes) {
        final video = VideoPet.fromMap(vidMap);

        // tenta resolver petUuid a partir do petId
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

        // se ainda não tem petUuid, não dá pra subir
        if (video.petUuid == null || video.caminhoLocal == null) continue;

        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/upload/video/'),
          );
          request.fields['pet_uuid'] = video.petUuid!;
          request.files.add(await http.MultipartFile.fromPath('file', video.caminhoLocal));

          final streamed = await request.send();
          final response = await http.Response.fromStream(streamed);
          final body = _decodeBodySafe(response.body);

          if (response.statusCode == 200 || response.statusCode == 201) {
            video.uuid = body['uuid']?.toString();
            video.sincronizado = true;
            await dbHelper.updateVideo(video);
            dadosAtualizados = true;
          }
        } catch (_) {}
      }

      // download completo
      await baixarTudoDoBackend();
    } finally {
      _isSyncing = false;
      if (dadosAtualizados && onSyncComplete != null) {
        onSyncComplete!();
      }
    }
  }
}