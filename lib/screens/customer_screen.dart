import 'package:flutter/material.dart';

import '../services/api_service.dart';

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

  Widget cards(List<dynamic> data, Widget Function(dynamic) build) =>
      data.isEmpty
      ? const Center(child: Text('No hay elementos vigentes.'))
      : ListView(
          padding: const EdgeInsets.all(16),
          children: data.map(build).toList(),
        );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Mis compras y beneficios'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Cupones'),
            Tab(text: 'Notas'),
            Tab(text: 'Solicitar cambio'),
            Tab(text: 'Avisos'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      cards(
                        coupons,
                        (c) => Card(
                          child: ListTile(
                            title: Text(c['nombre']),
                            subtitle: SelectableText(
                              "${c['codigo']}\n${c['valor']} ${c['tipo'] == 'MONTO' ? 'Bs.' : '%'}\nVence ${c['fecha_vencimiento']}\n${restrictions(c)}",
                            ),
                          ),
                        ),
                      ),
                      cards(
                        notes,
                        (n) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              "${n['codigo_nota']}\n${n['tipo_solicitud']}\n${n['prenda_devuelta_info']}\n${n['mensaje_notificacion']}\nVence ${n['fecha_expiracion']}",
                            ),
                          ),
                        ),
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          select(
                            'Compra',
                            purchases
                                .map(
                                  (p) => {
                                    'id': p['id'],
                                    'nombre':
                                        "Compra #${p['id']} · Bs. ${p['total']}",
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
                            'Prenda comprada',
                            details
                                .map(
                                  (d) => {
                                    'id': d['id'],
                                    'nombre':
                                        "${productName(d['producto_id'])} · ${d['cantidad']} unidades",
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
