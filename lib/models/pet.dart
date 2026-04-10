class Pet {
  int? id;
  String? uuid;
  String? usuarioUuid;

  String nome;
  String tipo;

  /// Campos opcionais (backend permite null)
  String? sexo;
  String? raca;
  int? idade;
  double? peso;
  double? altura;

  String? fotoPath;

  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;

  bool sincronizado;

  Pet({
    this.id,
    this.uuid,
    this.usuarioUuid,
    required this.nome,
    required this.tipo,
    this.sexo,
    this.raca,
    this.idade,
    this.peso,
    this.altura,
    this.fotoPath,
    required this.dataCadastro,
    required this.dataUltimaAtualizacao,
    this.sincronizado = false,
  });

  /// Ano de nascimento aproximado (só se idade existir)
  int? get anoNascimento =>
      idade != null ? DateTime.now().year - idade! : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'usuario_uuid': usuarioUuid,
        'nome': nome,
        'tipo': tipo,
        'sexo': sexo,
        'raca': raca,
        'idade': idade,
        'peso': peso,
        'altura': altura,
        'foto_path': fotoPath,
        'data_cadastro': dataCadastro.toIso8601String(),
        'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
        'sincronizado': sincronizado ? 1 : 0,
      };

  factory Pet.fromMap(Map<String, dynamic> map) => Pet(
        id: map['id'] as int?,
        uuid: map['uuid'] as String?,
        usuarioUuid: map['usuario_uuid'] as String?,
        nome: (map['nome'] ?? '').toString(),
        tipo: (map['tipo'] ?? '').toString(),
        sexo: map['sexo']?.toString(),
        raca: map['raca']?.toString(),
        idade: map['idade'] is int
            ? map['idade']
            : map['idade'] != null
                ? int.tryParse(map['idade'].toString())
                : null,
        peso: map['peso'] is double
            ? map['peso']
            : map['peso'] != null
                ? double.tryParse(map['peso'].toString())
                : null,
        altura: map['altura'] is double
            ? map['altura']
            : map['altura'] != null
                ? double.tryParse(map['altura'].toString())
                : null,
        fotoPath: map['foto_path']?.toString(),
        dataCadastro: DateTime.parse(map['data_cadastro'].toString()),
        dataUltimaAtualizacao:
            DateTime.parse(map['data_ultima_atualizacao'].toString()),
        sincronizado: (map['sincronizado'] ?? 0) == 1,
      );
}