import 'dart:convert';

import 'offline_db_service.dart';
import 'api_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final OfflineDbService _db = OfflineDbService();
  final ApiService _api = ApiService();

  bool isSyncing = false;

  /// Descarga el catálogo y las sucursales del backend y los persiste en SQLite
  Future<Map<String, int>> descargarDatosParaOffline({
    int empresaId = 1,
  }) async {
    try {
      empresaId = await _api.getEmpresaId();
      await _api.referencias('tallas');
      await _api.referencias('colores');
      await _db.guardarReferencia(
        'inventarios',
        await _api.getJson('/cliente/existencias'),
      );
      final productos = await _api.getProductos(empresaId: empresaId);
      await _db.guardarCatalogoLocal(productos, empresaId: empresaId);

      final sucursales = await _api.getSucursales(empresaId: empresaId);
      await _db.guardarSucursalesLocal(sucursales, empresaId: empresaId);

      return {'productos': productos.length, 'sucursales': sucursales.length};
    } catch (e) {
      throw Exception('Fallo al descargar datos para modo offline: $e');
    }
  }

  /// Ejecuta la sincronización en lote hacia el backend respetando idempotencia y conflictos
  Future<Map<String, dynamic>> sincronizarTodo() async {
    if (isSyncing) {
      return {'status': 'busy', 'mensaje': 'Sincronización ya en curso'};
    }

    isSyncing = true;
    int ventasConfirmadas = 0;
    int ventasRechazadas = 0;
    int reservasConfirmadas = 0;
    int reservasRechazadas = 0;
    int duplicadasIgnoradas = 0;
    List<String> errores = [];

    try {
      // 1. Sincronizar Ventas Offline
      final ventasPendientes = await _db.getVentasPendientes();
      if (ventasPendientes.isNotEmpty) {
        final List<Map<String, dynamic>> loteVentas = [];

        for (var v in ventasPendientes) {
          List<dynamic> detalles = [];
          try {
            detalles = jsonDecode(v['detalles_json']);
          } catch (_) {}

          loteVentas.add({
            'operacion_uuid': v['operacion_uuid'],
            'empresa_id': v['empresa_id'],
            'origen': 'MOVIL_OFFLINE',
            'sucursal_id': v['sucursal_id'],
            'usuario_id': v['usuario_id'],
            'cliente_id': v['cliente_id'],
            'metodo_pago': v['metodo_pago'],
            'tipo_entrega': v['tipo_entrega'],
            'direccion_envio': v['direccion_envio'],
            'fecha': v['fecha'],
            'detalles': detalles,
          });
        }

        try {
          final res = await _api.sincronizarVentasLote(loteVentas);
          ventasConfirmadas = res['confirmadas'] ?? 0;
          ventasRechazadas = res['rechazadas'] ?? 0;
          duplicadasIgnoradas +=
              (res['duplicadas_ignoradas'] as num?)?.toInt() ?? 0;

          final resultados = res['resultados'] as List<dynamic>? ?? [];
          for (var r in resultados) {
            final uuid = r['operacion_uuid'];
            final estado = r['estado'];
            final motivo = r['mensaje'];
            if (estado != 'CONFIRMADA' && estado != 'RECHAZADA_CONFLICTO')
              continue;
            await _db.actualizarEstadoVenta(uuid, estado, motivo: motivo);
          }
        } catch (e) {
          errores.add('Ventas: $e');
        }
      }

      // 2. Sincronizar Reservas Offline
      final reservasPendientes = await _db.getReservasPendientes();
      if (reservasPendientes.isNotEmpty) {
        final List<Map<String, dynamic>> loteReservas = [];

        for (var r in reservasPendientes) {
          List<dynamic> detalles = [];
          try {
            detalles = jsonDecode(r['detalles_json']);
          } catch (_) {}

          loteReservas.add({
            'operacion_uuid': r['operacion_uuid'],
            'empresa_id': r['empresa_id'],
            'origen': 'MOVIL_OFFLINE',
            'sucursal_id': r['sucursal_id'],
            'usuario_id': r['usuario_id'],
            'fecha': r['fecha'],
            'detalles': detalles,
          });
        }

        try {
          final res = await _api.sincronizarReservasLote(loteReservas);
          reservasConfirmadas = res['confirmadas'] ?? 0;
          reservasRechazadas = res['rechazadas'] ?? 0;
          duplicadasIgnoradas +=
              (res['duplicadas_ignoradas'] as num?)?.toInt() ?? 0;

          final resultados = res['resultados'] as List<dynamic>? ?? [];
          for (var r in resultados) {
            final uuid = r['operacion_uuid'];
            final estado = r['estado'];
            final motivo = r['mensaje'];
            if (estado != 'CONFIRMADA' && estado != 'RECHAZADA_CONFLICTO')
              continue;
            await _db.actualizarEstadoReserva(uuid, estado, motivo: motivo);
          }
        } catch (e) {
          errores.add('Reservas: $e');
        }
      }

      return {
        'status': errores.isEmpty ? 'success' : 'partial_error',
        'ventas_confirmadas': ventasConfirmadas,
        'ventas_rechazadas': ventasRechazadas,
        'reservas_confirmadas': reservasConfirmadas,
        'reservas_rechazadas': reservasRechazadas,
        'duplicadas_ignoradas': duplicadasIgnoradas,
        'total_procesadas':
            ventasConfirmadas +
            ventasRechazadas +
            reservasConfirmadas +
            reservasRechazadas,
        'errores': errores,
      };
    } finally {
      isSyncing = false;
    }
  }
}
