class Pet {
  int? id;
  String? uuid;
  String? usuarioUuid;
  String nome;
  String tipo;
  String sexo;
  String raca;
  int idade;
  double peso;
  double altura;
  String? fotoPath;
  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;
  bool sincronizado;

  Pet({
    this.id, this.uuid, this.usuarioUuid, required this.nome, required this.tipo,
    required this.sexo, required this.raca, required this.idade, required this.peso,
    required this.altura, this.fotoPath, required this.dataCadastro,
    required this.dataUltimaAtualizacao, this.sincronizado = false,
  });

  int get anoNascimento => DateTime.now().year - idade;

  Map<String, dynamic> toMap() => {
    'id': id, 'uuid': uuid, 'usuario_uuid': usuarioUuid, 'nome': nome, 'tipo': tipo,
    'sexo': sexo, 'raca': raca, 'idade': idade, 'peso': peso, 'altura': altura, 'foto_path': fotoPath,
    'data_cadastro': dataCadastro.toIso8601String(),
    'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
    'sincronizado': sincronizado ? 1 : 0,
  };

  factory Pet.fromMap(Map<String, dynamic> map) => Pet(
    id: map['id'], uuid: map['uuid'], usuarioUuid: map['usuario_uuid'], nome: map['nome'],
    tipo: map['tipo'], sexo: map['sexo'], raca: map['raca'], idade: map['idade'],
    peso: map['peso'], altura: map['altura'], fotoPath: map['foto_path'],
    dataCadastro: DateTime.parse(map['data_cadastro']),
    dataUltimaAtualizacao: DateTime.parse(map['data_ultima_atualizacao']),
    sincronizado: map['sincronizado'] == 1,
  );
}
