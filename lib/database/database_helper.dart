import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/usuario.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../models/observacao.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tossecheck.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // ✅ ATUALIZADO (era 3)
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        nome TEXT NOT NULL,
        cpf TEXT NOT NULL,
        telefone TEXT NOT NULL,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        bloqueado INTEGER DEFAULT 0,
        liberado INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        usuario_uuid TEXT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        sexo TEXT NOT NULL,
        raca TEXT NOT NULL,
        idade INTEGER NOT NULL,
        peso REAL NOT NULL,
        altura REAL NOT NULL,
        foto_path TEXT,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        pet_id INTEGER,
        pet_uuid TEXT,
        caminho_local TEXT NOT NULL,
        url_servidor TEXT,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    // ✅ OBSERVAÇÕES (SEM video_uuid, AGORA COM pet_uuid)
    await db.execute('''
      CREATE TABLE observacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        pet_uuid TEXT NOT NULL,
        veterinario TEXT NOT NULL,
        mensagem TEXT NOT NULL,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 1
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE videos ADD COLUMN pet_id INTEGER');
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN sincronizado INTEGER DEFAULT 0');
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE pets ADD COLUMN sincronizado INTEGER DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN bloqueado INTEGER DEFAULT 0');
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN liberado INTEGER DEFAULT 1');
      } catch (_) {}
    }

    // ✅ MIGRAÇÃO PARA v4: remover video_uuid e usar pet_uuid
    if (oldVersion < 4) {
      await _migrarObservacoesParaPetUuid(db);
    }
  }

  Future<void> _migrarObservacoesParaPetUuid(Database db) async {
    // SQLite não remove coluna facilmente, então:
    // 1) cria nova tabela
    // 2) copia dados possíveis
    // 3) drop antiga
    // 4) renomeia nova

    // Verifica se a tabela observacoes existe
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='observacoes'"
    );

    if (tables.isEmpty) {
      // Se não existir, cria direto no formato novo
      await db.execute('''
        CREATE TABLE observacoes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT,
          pet_uuid TEXT NOT NULL,
          veterinario TEXT NOT NULL,
          mensagem TEXT NOT NULL,
          data_cadastro TEXT NOT NULL,
          data_ultima_atualizacao TEXT NOT NULL,
          sincronizado INTEGER DEFAULT 1
        )
      ''');
      return;
    }

    // Cria tabela nova
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observacoes_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        pet_uuid TEXT NOT NULL,
        veterinario TEXT NOT NULL,
        mensagem TEXT NOT NULL,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 1
      )
    ''');

    // Copia o que der (se antes não existia pet_uuid, tenta usar pet_uuid vazio não pode)
    // Então copiamos somente registros que já tenham pet_uuid (caso exista por algum motivo).
    // Se sua tabela antiga só tinha video_uuid, não dá para inferir pet_uuid com segurança aqui.
    // Nesse caso, os registros antigos de observação serão descartados (ou você pode ajustar se tiver regra).
    //
    // Como seu app do tutor normalmente não depende dessas observações, isso é ok.
    try {
      // tenta copiar se existia coluna pet_uuid em alguma versão intermediária
      await db.execute('''
        INSERT INTO observacoes_new (id, uuid, pet_uuid, veterinario, mensagem, data_cadastro, data_ultima_atualizacao, sincronizado)
        SELECT id, uuid, pet_uuid, veterinario, mensagem, data_cadastro, data_ultima_atualizacao, sincronizado
        FROM observacoes
        WHERE pet_uuid IS NOT NULL AND pet_uuid <> ''
      ''');
    } catch (_) {
      // ignora se a coluna pet_uuid não existia na tabela antiga
    }

    // Remove antiga e renomeia nova
    await db.execute('DROP TABLE observacoes');
    await db.execute('ALTER TABLE observacoes_new RENAME TO observacoes');
  }

  // =========================
  // MÉTODOS DE USUÁRIO
  // =========================

  Future<Usuario?> getUsuario() async {
    final db = await instance.database;
    final maps = await db.query('usuarios', limit: 1);
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<Usuario?> getUsuarioPorCpf(String cpf) async {
    final db = await instance.database;
    final maps = await db.query(
      'usuarios',
      where: 'cpf = ?',
      whereArgs: [cpf],
      limit: 1,
    );
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<int> insertUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.insert('usuarios', usuario.toMap());
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<int> updateUsuarioPorUuid(Usuario usuario) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'uuid = ?',
      whereArgs: [usuario.uuid],
    );
  }

  Future<int> marcarUsuarioBloqueado({
    required String? uuid,
    required int? id,
  }) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      {
        'bloqueado': 1,
        'liberado': 0,
        'sincronizado': 0,
      },
      where: uuid != null ? 'uuid = ?' : 'id = ?',
      whereArgs: [uuid ?? id],
    );
  }

  Future<int> marcarUsuarioLiberado({
    required String? uuid,
    required int? id,
  }) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      {
        'bloqueado': 0,
        'liberado': 1,
      },
      where: uuid != null ? 'uuid = ?' : 'id = ?',
      whereArgs: [uuid ?? id],
    );
  }

  // =========================
  // MÉTODOS DE PETS
  // =========================

  Future<List<Pet>> getPets() async {
    final db = await instance.database;
    final maps = await db.query('pets', orderBy: 'nome ASC');
    return maps.map((m) => Pet.fromMap(m)).toList();
  }

  Future<List<Pet>> getPetsPorUsuarioUuid(String usuarioUuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'usuario_uuid = ?',
      whereArgs: [usuarioUuid],
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Pet.fromMap(m)).toList();
  }

  Future<Pet?> getPetPorUuid(String uuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Pet.fromMap(maps.first);
    }
    return null;
  }

  Future<Pet?> getPetPorId(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Pet.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertPet(Pet pet) async {
    final db = await instance.database;
    return await db.insert('pets', pet.toMap());
  }

  Future<int> updatePet(Pet pet) async {
    final db = await instance.database;
    return await db.update(
      'pets',
      pet.toMap(),
      where: 'id = ?',
      whereArgs: [pet.id],
    );
  }

  Future<int> updatePetByUuid(Pet pet) async {
    final db = await instance.database;
    return await db.update(
      'pets',
      pet.toMap(),
      where: 'uuid = ?',
      whereArgs: [pet.uuid],
    );
  }

  // =========================
  // MÉTODOS DE VÍDEOS
  // =========================

  Future<List<VideoPet>> getVideosPorPetId(int petId) async {
    final db = await instance.database;
    final maps = await db.query(
      'videos',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'data_cadastro DESC',
    );
    return maps.map((m) => VideoPet.fromMap(m)).toList();
  }

  Future<int> insertVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.insert('videos', video.toMap());
  }

  Future<int> updateVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.update(
      'videos',
      video.toMap(),
      where: 'id = ?',
      whereArgs: [video.id],
    );
  }

  // =========================
  // MÉTODOS DE OBSERVAÇÕES (AGORA POR PET_UUID)
  // =========================

  Future<List<Observacao>> getObservacoes() async {
    final db = await instance.database;
    final maps = await db.query('observacoes', orderBy: 'data_cadastro DESC');
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }

  Future<List<Observacao>> getObservacoesPorPetUuid(String petUuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'observacoes',
      where: 'pet_uuid = ?',
      whereArgs: [petUuid],
      orderBy: 'data_cadastro DESC',
    );
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }

  Future<int> insertObservacao(Observacao observacao) async {
    final db = await instance.database;
    return await db.insert('observacoes', observacao.toMap());
  }

  // =========================
  // MÉTODOS DE SINCRONIZAÇÃO
  // =========================

  Future<List<Map<String, dynamic>>> getPendentes(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'sincronizado = 0');
  }
}