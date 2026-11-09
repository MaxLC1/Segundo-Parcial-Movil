import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/offline_db_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cart = CartService();
  final ApiService _api = ApiService();
  final OfflineDbService _db = OfflineDbService();

  bool _isLoading = false;
  bool _isLoadingSucursales = true;
  List<dynamic> _sucursales = [];
  int? _selectedSucursalId;

  String _tipoEntrega = 'Recojo en Sucursal';
  String _direccionEnvio = '';
  String _metodoPago = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _loadSucursales();
  }

  Future<void> _loadSucursales() async {
    try {
      final sucursales = await _api.getSucursales();
      await _db.guardarSucursalesLocal(sucursales);
      setState(() {
        _sucursales = sucursales;
        _isLoadingSucursales = false;
      });
    } catch (e) {
      final localSucursales = await _db.getSucursalesLocal();
      if (!mounted) return;
      if (localSucursales.isNotEmpty) {
        setState(() {
          _sucursales = localSucursales;
          _isLoadingSucursales = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando sucursales: $e')),
        );
        setState(() => _isLoadingSucursales = false);
      }
    }
  }

  void _procesarOrden() {
    if (_cart.items.isEmpty) return;

    if (_selectedSucursalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una sucursal para tu reserva.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_tipoEntrega == 'Envío a Domicilio' && _direccionEnvio.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una dirección de envío.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_metodoPago == 'QR') {
      _mostrarModalQR();
    } else if (_metodoPago == 'Stripe') {
      _mostrarModalStripe();
    } else {
      _confirmarPedidoFinal();
    }
  }

  void _mostrarModalQR() {
    bool isVerifying = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(
              isSuccess ? '¡Pago Exitoso!' : 'Pago con QR',
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSuccess) ...[
                  const Text(
                    'Monto a pagar:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Bs ${_cart.total}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=Monto:${_cart.total}',
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isVerifying) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Verificando pago...',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ] else ...[
                    const Text(
                      'Escanea para pagar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu pago ha sido procesado.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ],
            ),
            actions: [
              if (!isSuccess && !isVerifying)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              if (!isSuccess && !isVerifying)
                TextButton(
                  onPressed: () async {
                    setStateModal(() => isVerifying = true);
                    await Future.delayed(const Duration(seconds: 2));
                    setStateModal(() {
                      isVerifying = false;
                      isSuccess = true;
                    });
                    await Future.delayed(const Duration(seconds: 1));
                    if (context.mounted) {
                      Navigator.pop(context);
                      _confirmarPedidoFinal();
                    }
                  },
                  child: const Text('Verificar Pago'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarModalStripe() {
    bool isProcessing = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: Text(
              isSuccess ? '¡Pago Exitoso!' : 'Pago con Tarjeta',
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSuccess) ...[
                  const Text(
                    'Monto a pagar:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Bs ${_cart.total}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      CardNumberFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Número de Tarjeta',
                      hintText: '0000 0000 0000 0000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            ExpirationDateFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            hintText: '12/25',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'CVC',
                            hintText: '123',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Procesando...',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu pago ha sido procesado.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ],
            ),
            actions: [
              if (!isSuccess && !isProcessing)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              if (!isSuccess && !isProcessing)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    setStateModal(() => isProcessing = true);
                    await Future.delayed(const Duration(seconds: 2));
                    setStateModal(() {
                      isProcessing = false;
                      isSuccess = true;
                    });
                    await Future.delayed(const Duration(seconds: 1));
                    if (context.mounted) {
                      Navigator.pop(context);
                      _confirmarPedidoFinal();
                    }
                  },
                  child: const Text('Pagar'),
                ),
            ],
          );
        },
      ),
    );
  }

  String? _operationUuid;
  Future<void> _confirmarPedidoFinal() async {
    _operationUuid ??= const Uuid().v4();
    setState(() => _isLoading = true);
    try {
      if (_tipoEntrega == 'Recojo en Sucursal') {
        await _api.crearReserva(
          _cart.items,
          _selectedSucursalId!,
          operacionUuid: _operationUuid,
        );
      } else {
        await _api.crearVenta(
          _cart.items,
          'Delivery',
          _direccionEnvio,
          _metodoPago,
          sucursalId: _selectedSucursalId,
          operacionUuid: _operationUuid,
        );
      }

      if (!mounted) return;
      _operationUuid = null;
      _cart.clear(); // Limpiamos el carrito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pedido online confirmado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (e is ApiException ||
          (_tipoEntrega != 'Recojo en Sucursal' && _metodoPago != 'Efectivo')) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e. Sin conexión solo se admite efectivo.'),
            ),
          );
        return;
      }
      // Conservar operaciones únicamente ante un fallo de comunicación.
      try {
        final token = await _api.getToken();
        int userId = 1;
        if (token != null) {
          final decoded = _api.decodeJwt(token);
          userId = decoded['id'] ?? 1;
        }

        final detalles = _cart.items
            .map(
              (item) => {
                'producto_id': item.productoId,
                'talla_id': item.tallaId,
                'color_id': item.colorId,
                'cantidad': item.cantidad,
                'precio_unitario': item.precioUnitario,
                'subtotal': item.cantidad * item.precioUnitario,
              },
            )
            .toList();

        String uuid;
        if (_tipoEntrega == 'Recojo en Sucursal') {
          uuid = await _db.registrarReservaOffline(
            sucursalId: _selectedSucursalId ?? 1,
            operationUuid: _operationUuid,
            usuarioId: userId,
            total: _cart.total,
            detalles: detalles,
          );
        } else {
          uuid = await _db.registrarVentaOffline(
            sucursalId: _selectedSucursalId ?? 1,
            operationUuid: _operationUuid,
            usuarioId: userId,
            metodoPago: _metodoPago,
            tipoEntrega: _tipoEntrega,
            direccionEnvio: _direccionEnvio,
            total: _cart.total,
            detalles: detalles,
          );
        }

        if (!mounted) return;
        _operationUuid = null;
        _cart.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Guardado en SQLite local (UUID: ${uuid.substring(0, 8)}...). Sincronización pendiente.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (dbError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e / SQLite: $dbError'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bolsa de Reservas'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          if (_cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Vaciar bolsa',
              onPressed: () => _cart.clear(),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) {
          if (_cart.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEDD5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tu bolsa de reservas está vacía',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explora nuestro catálogo y selecciona las prendas que deseas reservar.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _cart.items.length,
                  itemBuilder: (context, index) {
                    final item = _cart.items[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.checkroom,
                                color: Color(0xFFEA580C),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (item.tallaName != 'N/A')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Talla: ${item.tallaName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      if (item.colorName != 'N/A')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Color: ${item.colorName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bs ${item.precioUnitario} c/u',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Bs ${item.subtotal}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          _cart.decrementQuantity(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item.cantidad}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          _cart.incrementQuantity(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Footer con selección de sucursal y total
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tipo de Entrega
                    DropdownButtonFormField<String>(
                      value: _tipoEntrega,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '¿Cómo quieres recibir tu pedido?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: ['Recojo en Sucursal', 'Envío a Domicilio'].map((
                        String val,
                      ) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(val, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (newValue) =>
                          setState(() => _tipoEntrega = newValue!),
                    ),
                    const SizedBox(height: 12),

                    // Selector de Sucursal (Solo si es Recojo)
                    if (true)
                      if (_isLoadingSucursales)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<int>(
                          value: _selectedSucursalId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Selecciona una Sucursal',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _sucursales.map<DropdownMenuItem<int>>((
                            sucursal,
                          ) {
                            return DropdownMenuItem<int>(
                              value: sucursal['id'],
                              child: Text(
                                '${sucursal['nombre']} - ${sucursal['direccion']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) =>
                              setState(() => _selectedSucursalId = newValue),
                        ),

                    if (_tipoEntrega == 'Envío a Domicilio') ...[
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Dirección de Envío',
                          hintText: 'Ej: Calle 123, Zona Sur',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) => _direccionEnvio = val,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Método de pago para ambos (Delivery y Recojo)
                    DropdownButtonFormField<String>(
                      value: _metodoPago,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Método de Pago',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: ['Efectivo', 'QR', 'Stripe'].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(
                            val == 'Efectivo'
                                ? 'Efectivo al recibir'
                                : (val == 'QR'
                                      ? 'Pago con QR'
                                      : 'Tarjeta Stripe'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) =>
                          setState(() => _metodoPago = newValue!),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Bs ${_cart.total}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _procesarOrden,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _tipoEntrega == 'Recojo en Sucursal'
                                    ? 'CONFIRMAR RESERVA'
                                    : 'CONFIRMAR PEDIDO',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
}

// Formatters para Tarjeta
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class ExpirationDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length && i < 2) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
