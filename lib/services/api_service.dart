import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/videopet.dart';

class ApiService {
  // Padrão Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL para testar no emulador rodando o Django no próprio PC
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  bool _isSyncing = false;
  Function? onSyncComplete;

  void iniciarListenerDeConexao() {
    print('📡 [LISTENER] Configurando ouvinte de rede...');
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
        print('📡 [LISTENER] Internet detectada. Iniciando sync automático...');
        sincronizarGeral();
      }
    });
  }

  Future<bool> hasInternet() async {
    var result = await (Connectivity().checkConnectivity());
    return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
  }

  Future<void> sincronizarGeral() async {
    if (_isSyncing) return;
    if (!await hasInternet()) return;

    _isSyncing = true;
    bool dadosAtualizados = false; 
    final dbHelper = DatabaseHelper.instance;

    try {
      print('\n🔄 [SYNC] ========= INICIANDO COLETA DE DADOS =========');

      // ==========================================
      // 1. SINCRONIZAR USUÁRIO
      // ==========================================
      final usuarioLocal = await dbHelper.getUsuario();
      if (usuarioLocal == null) {
        print('⚠️ [SYNC] Nenhum usuário local encontrado.');
        _isSyncing = false;
        return;
      }
      
      if (!usuarioLocal.sincronizado) {
        print('👤 [SYNC USUÁRIO] Enviando: ${usuarioLocal.nome}');
        final res = await http.post(
          Uri.parse('$baseUrl/sync/usuario'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nome': usuarioLocal.nome, 
            'cpf': usuarioLocal.cpf, 
            'telefone': usuarioLocal.telefone
          }),
        );
        
        if (res.statusCode == 200 || res.statusCode == 201) {
          usuarioLocal.uuid = jsonDecode(res.body)['uuid'];
          usuarioLocal.sincronizado = true;
          await dbHelper.updateUsuario(usuarioLocal);
          dadosAtualizados = true;
          print('✅ [SYNC USUÁRIO] Sincronizado! UUID: ${usuarioLocal.uuid}');
        } else {
          // 👉 O DETETIVE: Vai imprimir o motivo da recusa do Django!
          print('❌ [ERRO BACKEND USUÁRIO] Status: ${res.statusCode} | Resposta: ${res.body}');
        }
      }

      if (usuarioLocal.uuid == null) {
         print('⚠️ [SYNC] Usuário sem UUID. Abortando o envio de pets e vídeos.');
         _isSyncing = false;
         return;
      }

      // ==========================================
      // 2. SINCRONIZAR PETS PENDENTES
      // ==========================================
      final petsPendentesMaps = await dbHelper.getPendentes('pets');
      for (var petMap in petsPendentesMaps) {
        var pet = Pet.fromMap(petMap);
        print('🐶 [SYNC PETS] Enviando pet: ${pet.nome}');
        final res = await http.post(
          Uri.parse('$baseUrl/sync/pet'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'usuario_uuid': usuarioLocal.uuid, 
            'nome': pet.nome, 
            'tipo': pet.tipo,
            'sexo': pet.sexo, 
            'raca': pet.raca, 
            'idade': pet.idade, 
            'peso': pet.peso, 
            'altura': pet.altura,
          }),
        );
        
        if (res.statusCode == 200 || res.statusCode == 201) {
          pet.uuid = jsonDecode(res.body)['uuid'];
          pet.usuarioUuid = usuarioLocal.uuid;
          pet.sincronizado = true;
          await dbHelper.updatePet(pet);
          dadosAtualizados = true;
          print('✅ [SYNC PETS] Pet ${pet.nome} sincronizado!');
        } else {
          print('❌ [ERRO BACKEND PET] Status: ${res.statusCode} | Resposta: ${res.body}');
        }
      }

      // ==========================================
      // 3. SINCRONIZAR VÍDEOS PENDENTES
      // ==========================================
      final videosPendentesMaps = await dbHelper.getPendentes('videos');
      for (var vidMap in videosPendentesMaps) {
        var video = VideoPet.fromMap(vidMap);
        
        // Busca o UUID atualizado do pet se foi criado offline
        if (video.petUuid == null && video.petId != null) {
          var petsList = await dbHelper.getPets();
          try {
            var dono = petsList.firstWhere((p) => p.id == video.petId);
            if (dono.uuid != null) {
              video.petUuid = dono.uuid;
              await dbHelper.updateVideo(video);
            } else {
               continue; // Pet ainda não subiu, pula o vídeo por enquanto
            }
          } catch(e) { continue; }
        }

        if (video.petUuid == null) continue;

        print('📹 [SYNC VÍDEOS] Enviando arquivo físico de mídia...');
        try {
          var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/video'));
          request.fields['pet_uuid'] = video.petUuid!;
          request.files.add(await http.MultipartFile.fromPath('file', video.caminhoLocal));
          
          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            video.uuid = jsonDecode(response.body)['uuid'];
            video.sincronizado = true;
            await dbHelper.updateVideo(video);
            dadosAtualizados = true;
            print('✅ [SYNC VÍDEOS] Upload realizado com sucesso!');
          } else {
            print('❌ [ERRO BACKEND VÍDEO] Status: ${response.statusCode} | Resposta: ${response.body}');
          }
        } catch(e) {
           print('❌ [SYNC VÍDEOS] Falha na rede ao enviar vídeo: $e');
        }
      }

    } catch (e) {
      print('🚨 [ERRO NETWORK] Falha geral na comunicação: $e');
    } finally {
      _isSyncing = false;
      print('🔄 [SYNC] ========= FIM DA COLETA =========\n');
      
      // Avisa a interface gráfica para recarregar se algo mudou
      if (dadosAtualizados && onSyncComplete != null) {
        onSyncComplete!();
      }
    }
  }
}