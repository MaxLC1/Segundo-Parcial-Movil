import 'package:flutter/material.dart';

import '../services/offline_db_service.dart';
import '../services/offline_sync_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class OfflineSyncScreen extends StatefulWidget {
  const OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen>
    with SingleTickerProviderStateMixin {
  final OfflineDbService _db = OfflineDbService();
  final OfflineSyncService _sync = OfflineSyncService();

  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController(
    text: ApiService.baseUrl,
  );

  List<Map<String, dynamic>> _ventas = [];
  List<Map<String, dynamic>> _reservas = [];
  int _pendientesCount = 0;
  bool _isLoading = false;
  String? _syncFeedback;
  Color _feedbackColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatosLocales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosLocales() async {
    setState(() => _isLoading = true);
    try {
      final ventas = await _db.getTodasVentasOffline();
      final reservas = await _db.getTodasReservasOffline();
      final pendientes = await _db.contarOperacionesPendientes();
      if (!mounted) return;

      setState(() {
        _ventas = ventas;
        _reservas = reservas;
        _pendientesCount = pendientes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando SQLite local: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarUrlBase() async {
    final nuevaUrl = _urlController.text.trim();
    if (nuevaUrl.isNotEmpty) {
      await ApiService.setBaseUrl(nuevaUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL base actualizada a: $nuevaUrl'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _descargarCatalogoOffline() async {
    setState(() {
      _isLoading = true;
      _syncFeedback = 'Descargando catálogo y sucursales a SQLite...';
      _feedbackColor = Colors.blue;
    });

    try {
      final res = await _sync.descargarDatosParaOffline();
      setState(() {
        _syncFeedback =
            '¡Éxito! Se guardaron ${res['productos']} productos y ${res['sucursales']} sucursales en SQLite local.';
        _feedbackColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _syncFeedback = 'Error al descargar datos: $e';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ejecutarSincronizacion() async {
    setState(() {
      _isLoading = true;
      _syncFeedback = 'Sincronizando lote con el backend...';
      _feedbackColor = Colors.orange;
    });

    try {
      final report = await _sync.sincronizarTodo();
      await _cargarDatosLocales();

      final int confirmadas =
          (report['ventas_confirmadas'] ?? 0) +
          (report['reservas_confirmadas'] ?? 0);
      final int rechazadas =
          (report['ventas_rechazadas'] ?? 0) +
          (report['reservas_rechazadas'] ?? 0);
      final int duplicadas = report['duplicadas_ignoradas'] ?? 0;

      setState(() {
        _syncFeedback =
            'Sincronización finalizada:\n'
            '• Confirmadas: $confirmadas\n'
            '• Conflictos/Rechazadas: $rechazadas\n'
            '• Duplicadas ignoradas (Idempotencia RNF05): $duplicadas';
        _feedbackColor = rechazadas > 0 ? Colors.deepOrange : Colors.green;
      });
    } catch (e) {
      setState(() {
        _syncFeedback = 'Error en la sincronización: $e';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBadgeEstado(String estado, String? motivo) {
    Color bg;
    Color fg = Colors.white;
    String label = estado;

    switch (estado) {
      case 'CONFIRMADA':
        bg = Colors.green.shade600;
        break;
      case 'RECHAZADA_CONFLICTO':
        bg = Colors.red.shade600;
        label = 'CONFLICTO DE STOCK';
        break;
      case 'ENVIADA':
        bg = Colors.blue.shade600;
        break;
      case 'REGISTRADA_LOCAL':
      default:
        bg = Colors.orange.shade700;
        label = 'REGISTRADA LOCAL (PENDIENTE)';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (motivo != null && motivo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            motivo,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Persistencia SQLite & Sincronización'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar datos locales',
            onPressed: _cargarDatosLocales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Informativo Desafío III
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estado de Cola Local SQLite:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _pendientesCount > 0
                            ? Colors.orange
                            : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _pendientesCount > 0
                            ? '$_pendientesCount pendientes'
                            : 'Al día',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Input de URL Backend
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            labelText: 'URL API Backend',
                            labelStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _guardarUrlBase,
                      child: const Text(
                        'Guardar',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Acciones de Descarga y Sincronización
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text(
                      'Descargar Catálogo',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _isLoading ? null : _descargarCatalogoOffline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text(
                      'Sincronizar Lote',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isLoading ? null : _ejecutarSincronizacion,
                  ),
                ),
              ],
            ),
          ),

          // Feedback de Sincronización
          if (_syncFeedback != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _feedbackColor.withOpacity(0.1),
                border: Border.all(color: _feedbackColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _feedbackColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _syncFeedback!,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_syncFeedback!.toLowerCase().contains('vencida') ||
                            _syncFeedback!.toLowerCase().contains('inválida') ||
                            _syncFeedback!.toLowerCase().contains('invalida') ||
                            _syncFeedback!.toLowerCase().contains('inicie') ||
                            _syncFeedback!.toLowerCase().contains('401')) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              await ApiService().logout();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              'Tu sesión expiró. Toca aquí para Iniciar Sesión nuevamente.',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Barra de Pestañas
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFEA580C),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFEA580C),
            tabs: [
              Tab(text: 'Ventas Offline (${_ventas.length})'),
              Tab(text: 'Reservas Offline (${_reservas.length})'),
            ],
          ),

          // Listado de Operaciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Pestaña 1: Ventas Offline
                      _ventas.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay ventas registradas en SQLite local.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _ventas.length,
                              itemBuilder: (context, index) {
                                final v = _ventas[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total: Bs ${v['total']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            _buildBadgeEstado(
                                              v['estado_sincronizacion'] ??
                                                  'REGISTRADA_LOCAL',
                                              v['motivo_rechazo'],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'UUID: ${v['operacion_uuid']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          'Método: ${v['metodo_pago']} | Sucursal #${v['sucursal_id']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Fecha: ${v['fecha']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Pestaña 2: Reservas Offline
                      _reservas.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay reservas registradas en SQLite local.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _reservas.length,
                              itemBuilder: (context, index) {
                                final r = _reservas[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Reserva en Sucursal #${r['sucursal_id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            _buildBadgeEstado(
                                              r['estado_sincronizacion'] ??
                                                  'REGISTRADA_LOCAL',
                                              r['motivo_rechazo'],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'UUID: ${r['operacion_uuid']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          'Total: Bs ${r['total']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Fecha: ${r['fecha']}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
