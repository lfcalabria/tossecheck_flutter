class VideoPet {
  int? id;
  String? uuid;

  /// Para funcionar offline
  int? petId;

  /// UUID do pet no backend (quando já sincronizado)
  String? petUuid;

  /// Caminho local do arquivo gravado no dispositivo
  String caminhoLocal;

  /// URL retornada pelo servidor após upload (se você armazenar)
  String? urlServidor;

  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;

  bool sincronizado;

  VideoPet({
    this.id,
    this.uuid,
    this.petId,
    this.petUuid,
    required this.caminhoLocal,
    this.urlServidor,
    required this.dataCadastro,
    required this.dataUltimaAtualizacao,
    this.sincronizado = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'pet_id': petId,
        'pet_uuid': petUuid,
        'caminho_local': caminhoLocal,
        'url_servidor': urlServidor,
        'data_cadastro': dataCadastro.toIso8601String(),
        'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
        'sincronizado': sincronizado ? 1 : 0,
      };

  factory VideoPet.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v == 1;
      return v.toString() == '1' || v.toString().toLowerCase() == 'true';
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return VideoPet(
      id: parseInt(map['id']),
      uuid: map['uuid']?.toString(),
      petId: parseInt(map['pet_id']),
      petUuid: map['pet_uuid']?.toString(),
      caminhoLocal: (map['caminho_local'] ?? '').toString(),
      urlServidor: map['url_servidor']?.toString(),
      dataCadastro: parseDate(map['data_cadastro']),
      dataUltimaAtualizacao: parseDate(map['data_ultima_atualizacao']),
      sincronizado: parseBool(map['sincronizado']),
    );
  }
}