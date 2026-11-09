import 'dart:convert';

import 'api_service.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class OfflineDbService {
  static final OfflineDbService _instance = OfflineDbService._internal();
  factory OfflineDbService() => _instance;
  OfflineDbService._internal();

  static Database? _database;
  static String? _scope;
  final Map<String, Future<Database>> _opening = {};
  final Uuid _uuid = const Uuid();

  Future<Database> get database async {
    final token = await ApiService().getToken();
    final claims = token == null
        ? <String, dynamic>{}
        : ApiService().decodeJwt(token);
    final scope =
        "${claims['empresa_id'] ?? 'public'}_${claims['id'] ?? 'public'}";
    if (_database != null && _scope == scope) return _database!;
    _scope = scope;
    _database = await _opening.putIfAbsent(scope, () => _initDb(scope));
    return _database!;
  }

  Future<Database> _initDb(String scope) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fashionstore_mobile_$scope.db');

    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS referencias (clave TEXT PRIMARY KEY, datos TEXT)',
        );
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS referencias (clave TEXT PRIMARY KEY, datos TEXT)',
        );
        // 1. Tabla de Catálogo Local (Cache SQLite)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS catalogo_cache (
            id INTEGER PRIMARY KEY,
            empresa_id INTEGER,
            nombre TEXT,
            codigo TEXT,
            precio REAL,
            imagen_url TEXT,
            categoria_id INTEGER,
            fecha_guardado TEXT
          )
        ''');

        // 2. Tabla de Sucursales Local
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sucursales_cache (
            id INTEGER PRIMARY KEY,
            empresa_id INTEGER,
            nombre TEXT,
            direccion TEXT,
            ciudad_id INTEGER
          )
        ''');

        // 3. Tabla de Ventas Offline (Desafío III & IV)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ventas_offline (
            operacion_uuid TEXT PRIMARY KEY,
            empresa_id INTEGER,
            sucursal_id INTEGER,
            usuario_id INTEGER,
            cliente_id INTEGER,
            metodo_pago TEXT,
            tipo_entrega TEXT,
            direccion_envio TEXT,
            total REAL,
            detalles_json TEXT,
            fecha TEXT,
            estado_sincronizacion TEXT,
            motivo_rechazo TEXT
          )
        ''');

        // 4. Tabla de Reservas Offline
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reservas_offline (
            operacion_uuid TEXT PRIMARY KEY,
            empresa_id INTEGER,
            sucursal_id INTEGER,
            usuario_id INTEGER,
            total REAL,
            detalles_json TEXT,
            fecha TEXT,
            estado_sincronizacion TEXT,
            motivo_rechazo TEXT
          )
        ''');
      },
    );
  }

  // --- CATÁLOGO & SUCURSALES CACHE ---

  Future<void> guardarCatalogoLocal(
    List<dynamic> productos, {
    int empresaId = 1,
  }) async {
    final db = await database;
    final batch = db.batch();
    final fechaActual = DateTime.now().toIso8601String();

    await db.delete('catalogo_cache'); // Limpiar caché anterior

    for (var p in productos) {
      batch.insert('catalogo_cache', {
        'id': p['id'],
        'empresa_id': p['empresa_id'] ?? empresaId,
        'nombre': p['nombre'] ?? '',
        'codigo': p['codigo'] ?? '',
        'precio': (p['precio'] as num?)?.toDouble() ?? 0.0,
        'imagen_url': p['imagen_url'] ?? '',
        'categoria_id': p['categoria_id'] ?? 1,
        'fecha_guardado': fechaActual,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCatalogoLocal() async {
    final db = await database;
    return await db.query('catalogo_cache', orderBy: 'id ASC');
  }

  Future<void> guardarSucursalesLocal(
    List<dynamic> sucursales, {
    int empresaId = 1,
  }) async {
    final db = await database;
    final batch = db.batch();

    await db.delete('sucursales_cache');

    for (var s in sucursales) {
      batch.insert('sucursales_cache', {
        'id': s['id'],
        'empresa_id': s['empresa_id'] ?? empresaId,
        'nombre': s['nombre'] ?? '',
        'direccion': s['direccion'] ?? '',
        'ciudad_id': s['ciudad_id'] ?? 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getSucursalesLocal() async {
    final db = await database;
    return await db.query('sucursales_cache');
  }

  // --- REGISTRO DE VENTAS OFFLINE ---

  Future<String> registrarVentaOffline({
    required int sucursalId,
    required int usuarioId,
    required String metodoPago,
    required String tipoEntrega,
    required String direccionEnvio,
    required double total,
    required List<dynamic> detalles,
    int empresaId = 1,
    String? operationUuid,
    int? clienteId,
  }) async {
    final db = await database;
    empresaId = await ApiService().getEmpresaId();
    final String operacionUuid = operationUuid ?? _uuid.v4();
    final String fecha = DateTime.now().toIso8601String();

    await db.insert('ventas_offline', {
      'operacion_uuid': operacionUuid,
      'empresa_id': empresaId,
      'sucursal_id': sucursalId,
      'usuario_id': usuarioId,
      'cliente_id': clienteId ?? usuarioId,
      'metodo_pago': metodoPago,
      'tipo_entrega': tipoEntrega,
      'direccion_envio': direccionEnvio,
      'total': total,
      'detalles_json': jsonEncode(detalles),
      'fecha': fecha,
      'estado_sincronizacion': 'REGISTRADA_LOCAL',
      'motivo_rechazo': null,
    });

    return operacionUuid;
  }

  // --- REGISTRO DE RESERVAS OFFLINE ---

  Future<String> registrarReservaOffline({
    required int sucursalId,
    required int usuarioId,
    required double total,
    required List<dynamic> detalles,
    int empresaId = 1,
    String? operationUuid,
  }) async {
    final db = await database;
    empresaId = await ApiService().getEmpresaId();
    final String operacionUuid = operationUuid ?? _uuid.v4();
    final String fecha = DateTime.now().toIso8601String();

    await db.insert('reservas_offline', {
      'operacion_uuid': operacionUuid,
      'empresa_id': empresaId,
      'sucursal_id': sucursalId,
      'usuario_id': usuarioId,
      'total': total,
      'detalles_json': jsonEncode(detalles),
      'fecha': fecha,
      'estado_sincronizacion': 'REGISTRADA_LOCAL',
      'motivo_rechazo': null,
    });

    return operacionUuid;
  }

  // --- CONSULTAS Y ESTADOS DE COLA ---

  Future<List<Map<String, dynamic>>> getVentasPendientes() async {
    final db = await database;
    return await db.query(
      'ventas_offline',
      where: 'estado_sincronizacion = ?',
      whereArgs: ['REGISTRADA_LOCAL'],
      orderBy: 'fecha ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodasVentasOffline() async {
    final db = await database;
    return await db.query('ventas_offline', orderBy: 'fecha DESC');
  }

  Future<List<Map<String, dynamic>>> getReservasPendientes() async {
    final db = await database;
    return await db.query(
      'reservas_offline',
      where: 'estado_sincronizacion = ?',
      whereArgs: ['REGISTRADA_LOCAL'],
      orderBy: 'fecha ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTodasReservasOffline() async {
    final db = await database;
    return await db.query('reservas_offline', orderBy: 'fecha DESC');
  }

  Future<void> actualizarEstadoVenta(
    String uuid,
    String estado, {
    String? motivo,
  }) async {
    final db = await database;
    await db.update(
      'ventas_offline',
      {'estado_sincronizacion': estado, 'motivo_rechazo': motivo},
      where: 'operacion_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> actualizarEstadoReserva(
    String uuid,
    String estado, {
    String? motivo,
  }) async {
    final db = await database;
    await db.update(
      'reservas_offline',
      {'estado_sincronizacion': estado, 'motivo_rechazo': motivo},
      where: 'operacion_uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> contarOperacionesPendientes() async {
    final db = await database;
    final countVentas =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM ventas_offline WHERE estado_sincronizacion = 'REGISTRADA_LOCAL'",
          ),
        ) ??
        0;
    final countReservas =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM reservas_offline WHERE estado_sincronizacion = 'REGISTRADA_LOCAL'",
          ),
        ) ??
        0;
    return countVentas + countReservas;
  }

  Future<void> limpiarTodasOperaciones() async {
    final db = await database;
    await db.delete(
      'ventas_offline',
      where: "estado_sincronizacion = 'CONFIRMADA'",
    );
    await db.delete(
      'reservas_offline',
      where: "estado_sincronizacion = 'CONFIRMADA'",
    );
  }

  Future<void> guardarReferencia(String clave, dynamic datos) async {
    final db = await database;
    await db.insert('referencias', {
      'clave': clave,
      'datos': jsonEncode(datos),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<dynamic>> getReferencia(String clave) async {
    final db = await database;
    final rows = await db.query(
      'referencias',
      where: 'clave = ?',
      whereArgs: [clave],
    );
    return rows.isEmpty
        ? []
        : jsonDecode(rows.first['datos'] as String) as List<dynamic>;
  }
}
