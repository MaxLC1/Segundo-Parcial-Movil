import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'login_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final api = ApiService();
  List<dynamic> coupons = [],
      notes = [],
      purchases = [],
      alerts = [],
      products = [],
      sizes = [],
      colors = [];
  bool loading = true, saving = false;
  String? error;
  int? purchaseId, detailId, productId, sizeId, colorId;
  String type = 'Devolución Directa';
  final reason = TextEditingController();
  final quantity = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    reason.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait(
        [
          '/cliente/cupones',
          '/cliente/notas',
          '/cliente/compras',
          '/cliente/notificaciones',
          '/catalogo/productos',
          '/catalogo/tallas',
          '/catalogo/colores',
        ].map(api.getJson),
      );
      if (!mounted) return;
      setState(() {
        coupons = results[0];
        notes = results[1];
        purchases = results[2];
        alerts = results[3];
        products = results[4];
        sizes = results[5];
        colors = results[6];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          error = e.toString();
        });
    }
  }

  dynamic get purchase =>
      purchases.where((p) => p['id'] == purchaseId).firstOrNull;
  List<dynamic> get details => purchase?['detalles'] as List<dynamic>? ?? [];
  dynamic get detail => details.where((d) => d['id'] == detailId).firstOrNull;
  String productName(dynamic id) =>
      products.where((p) => p['id'] == id).firstOrNull?['nombre'] ??
      'Producto #$id';
  Widget select(
    String label,
    List<dynamic> items,
    int? value,
    void Function(int?) onChanged, {
    String keyName = 'nombre',
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<int>(
      key: ValueKey('$label-$value-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (i) => DropdownMenuItem<int>(
              value: i['id'] as int,
              child: Text('${i[keyName]}', overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
  Future<void> submit() async {
    if (purchaseId == null ||
        detailId == null ||
        reason.text.trim().length < 3) {
      setState(
        () => error = 'Selecciona la compra, la prenda e indica el motivo',
      );
      return;
    }
    setState(() => saving = true);
    try {
      await api.postJson('/cliente/solicitudes', {
        'venta_id': purchaseId,
        'detalle_venta_id': detailId,
        'cantidad': int.tryParse(quantity.text) ?? 0,
        'tipo_solicitud': type,
        'producto_nuevo_id': type == 'Devolución Directa'
            ? null
            : type == 'Cambio de Talla o Color'
            ? detail['producto_id']
            : productId,
        'talla_nueva_id': type == 'Devolución Directa' ? null : sizeId,
        'color_nuevo_id': type == 'Devolución Directa' ? null : colorId,
        'motivo': reason.text.trim(),
      });
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud registrada. Consulta tu nota en la pestaña Notas.',
            ),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String restrictions(dynamic coupon) {
    final criteria = coupon['criterios'] as Map? ?? {};
    final groups = {
      'productos': products,
      'tallas': sizes,
      'temporadas': products
          .map((p) => p['temporada'])
          .where((p) => p != null)
          .toList(),
      'categorias': products
          .map((p) => p['categoria'])
          .where((p) => p != null)
          .toList(),
    };
    final labels = {
      'productos': 'Prendas',
      'tallas': 'Tallas',
      'temporadas': 'Temporadas',
      'categorias': 'Categorías',
    };
    final result = groups.keys
        .where((key) => (criteria[key] as List? ?? []).isNotEmpty)
        .map(
          (key) =>
              '${labels[key]}: ${(criteria[key] as List).map((id) => groups[key]!.where((p) => p['id'] == id).firstOrNull?['nombre'] ?? '#$id').join(', ')}',
        )
        .join(' · ');
    return result.isEmpty ? 'Todo el catálogo' : result;
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final str = raw.toString();
    try {
      final dt = DateTime.parse(str);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      if (str.contains('T') && dt.hour != 0) {
        return '$day/$month/$year $hour:$min';
      }
      return '$day/$month/$year';
    } catch (_) {
      return str.split('T').first;
    }
  }

  Widget _buildReservaCard(dynamic p) {
    final detalles = p['detalles'] as List<dynamic>? ?? [];
    final estado = (p['estado_sincronizacion'] ?? 'CONFIRMADA').toString().toUpperCase();
    final bool esConfirmada = estado == 'CONFIRMADA';
    final tipoEntrega = p['tipo_entrega'] ?? 'Recojo en Sucursal';
    final esDomicilio = tipoEntrega.toString().toLowerCase().contains('domicilio') ||
        tipoEntrega.toString().toLowerCase().contains('envio');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Reserva #${p['id']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: esConfirmada ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: esConfirmada ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      color: esConfirmada ? Colors.green.shade800 : Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  esDomicilio ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    esDomicilio
                        ? 'Envío: ${p['direccion_envio'] ?? 'Dirección registrada'}'
                        : 'Recojo en Sucursal',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  _formatDate(p['fecha']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Icon(Icons.payment_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  p['metodo_pago'] ?? 'Efectivo',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: detalles.map((d) {
                    final pNombre = productName(d['producto_id']);
                    final cant = d['cantidad'] ?? 1;
                    final sub = d['subtotal'] ?? ((d['precio_unitario'] ?? 0) * cant);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.checkroom, size: 14, color: Color(0xFFEA580C)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$pNombre (x$cant)',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Bs $sub',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total de Reserva',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Bs ${p['total'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(dynamic c) {
    final String codigo = c['codigo'] ?? '';
    final String tipo = c['tipo'] ?? 'PORCENTAJE';
    final num valor = c['valor'] ?? 0;
    final valorTexto = tipo == 'MONTO' ? 'Bs $valor' : '$valor%';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      valorTexto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['nombre'] ?? 'Cupón de Descuento',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restrictions(c),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 16,
                          color: Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 6),
                        SelectableText(
                          codigo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Copiar código',
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Color(0xFFEA580C),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: codigo));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Código $codigo copiado al portapapeles'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      Text(
                        'Vence: ${_formatDate(c['fecha_vencimiento'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotaCard(dynamic n) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n['codigo_nota'] ?? 'Nota',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    n['tipo_solicitud'] ?? 'Devolución',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (n['prenda_devuelta_info'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Prenda: ${n['prenda_devuelta_info']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (n['mensaje_notificacion'] != null)
              Text(
                n['mensaje_notificacion'],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Vence: ${_formatDate(n['fecha_expiracion'])}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget cards(
    List<dynamic> data,
    Widget Function(dynamic) build, {
    String emptyMsg = 'No hay elementos vigentes.',
  }) =>
      data.isEmpty
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  emptyMsg,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      : ListView(
          padding: const EdgeInsets.all(16),
          children: data.map(build).toList(),
        );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mis compras y beneficios'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Mis Reservas'),
            Tab(icon: Icon(Icons.card_giftcard_outlined), text: 'Cupones'),
            Tab(icon: Icon(Icons.assignment_return_outlined), text: 'Notas'),
            Tab(icon: Icon(Icons.swap_horiz_outlined), text: 'Solicitar cambio'),
            Tab(icon: Icon(Icons.notifications_none_outlined), text: 'Avisos'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (error != null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (error!.toLowerCase().contains('vencida') ||
                            error!.toLowerCase().contains('inválida') ||
                            error!.toLowerCase().contains('invalida') ||
                            error!.toLowerCase().contains('inicie') ||
                            error!.toLowerCase().contains('401')) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.login),
                            label: const Text('Iniciar Sesión'),
                            onPressed: () async {
                              await api.logout();
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
                          ),
                        ],
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Pestaña 1: Mis Reservas
                      cards(
                        purchases,
                        _buildReservaCard,
                        emptyMsg: 'No tienes reservas ni compras registradas.',
                      ),
                      // Pestaña 2: Cupones
                      cards(
                        coupons,
                        _buildCouponCard,
                        emptyMsg: 'No tienes cupones vigentes en este momento.',
                      ),
                      // Pestaña 3: Notas de crédito
                      cards(
                        notes,
                        _buildNotaCard,
                        emptyMsg: 'No tienes notas de cambio o devolución vigentes.',
                      ),
                      // Pestaña 4: Solicitar cambio
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (purchases.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'No se encontraron compras confirmadas para este usuario. Realiza una reserva o compra primero.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          select(
                            '1. Selecciona Compra Reciente (Últimas 5)',
                            purchases
                                .take(5)
                                .map(
                                  (p) => {
                                    'id': p['id'],
                                    'nombre':
                                        "Compra #${p['id']} · Bs. ${p['total']} (${_formatDate(p['fecha'])})",
                                  },
                                )
                                .toList(),
                            purchaseId,
                            (v) => setState(() {
                              purchaseId = v;
                              detailId = null;
                            }),
                          ),
                          select(
                            purchaseId == null
                                ? '2. Prenda (Selecciona primero la compra arriba)'
                                : '2. Prenda a devolver o cambiar',
                            details
                                .map(
                                  (d) => {
                                    'id': d['id'],
                                    'nombre':
                                        "${productName(d['producto_id'])} · ${d['cantidad']} u. (Bs ${d['subtotal'] ?? d['precio_unitario']})",
                                  },
                                )
                                .toList(),
                            detailId,
                            (v) => setState(() => detailId = v),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            isExpanded: true,
                            items:
                                [
                                      'Devolución Directa',
                                      'Cambio por Mayor Valor',
                                      'Cambio por Menor Valor',
                                      'Cambio de Talla o Color',
                                    ]
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() {
                              type = v!;
                              productId = null;
                              sizeId = null;
                              colorId = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          if (type != 'Devolución Directa') ...[
                            if (type != 'Cambio de Talla o Color')
                              select(
                                'Nueva prenda',
                                products,
                                productId,
                                (v) => setState(() => productId = v),
                              ),
                            select(
                              'Talla',
                              sizes,
                              sizeId,
                              (v) => setState(() => sizeId = v),
                            ),
                            select(
                              'Color',
                              colors,
                              colorId,
                              (v) => setState(() => colorId = v),
                            ),
                          ],
                          TextField(
                            controller: quantity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                            ),
                          ),
                          TextField(
                            controller: reason,
                            maxLength: 255,
                            decoration: const InputDecoration(
                              labelText: 'Motivo',
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: saving ? null : submit,
                            child: Text(
                              saving ? 'Guardando…' : 'Registrar solicitud',
                            ),
                          ),
                        ],
                      ),
                      cards(
                        alerts,
                        (n) => Card(
                          child: ListTile(
                            title: Text(n['titulo']),
                            subtitle: Text(n['mensaje']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
