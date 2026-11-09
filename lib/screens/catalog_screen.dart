import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/offline_db_service.dart';
import 'ar_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ApiService _api = ApiService();
  final OfflineDbService _db = OfflineDbService();

  List<dynamic> productos = [];
  bool isLoading = true;
  bool isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    setState(() => isLoading = true);
    try {
      final data = await _api.getProductos();
      // Guardar automáticamente en SQLite para soporte offline (Desafío III)
      await _db.guardarCatalogoLocal(data);
      if (!mounted) return;
      setState(() {
        productos = data;
        isLoading = false;
        isOfflineMode = false;
      });
    } catch (e) {
      // Fallback a SQLite local si no hay conexión
      final localData = await _db.getCatalogoLocal();
      if (!mounted) return;
      if (localData.isNotEmpty) {
        setState(() {
          productos = localData;
          isLoading = false;
          isOfflineMode = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin conexión al servidor. Cargando catálogo guardado en SQLite local.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar catálogo y no hay datos offline: $e',
            ),
          ),
        );
        setState(() => isLoading = false);
      }
    }
  }

  void _configurarServidor() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Servidor Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En teléfono físico usa la IP de tu PC en la red Wi-Fi:\n'
              'http://192.168.100.4:8000/api/v1\n\n'
              'En emulador Android Studio:\n'
              'http://10.0.2.2:8000/api/v1',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL Base API',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    controller.text = 'http://34.230.18.9:8000/api/v1';
                  },
                  child: const Text('AWS Cloud (34.230.18.9)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    controller.text = 'http://127.0.0.1:8000/api/v1';
                  },
                  child: const Text('USB (127.0.0.1)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    controller.text = 'http://192.168.100.4:8000/api/v1';
                  },
                  child: const Text('Wi-Fi (192.168.100.4)'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiService.setBaseUrl(newUrl);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadProductos();
                }
              }
            },
            child: const Text('Guardar y Recargar'),
          ),
        ],
      ),
    );
  }

  void _abrirAR(String? url3d, String nombreProducto) {
    if (url3d == null || url3d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no tiene modelo 3D aún.')),
      );
      return;
    }

    // Navegar a la pantalla del Simulador AR
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ARScreen(url3d: url3d, nombreProducto: nombreProducto),
      ),
    );
  }

  void _mostrarOpcionesProducto(dynamic p) async {
    try {
      final tallas = await _api.referencias('tallas');
      final colores = await _api.referencias('colores');
      if (tallas.isEmpty || colores.isEmpty)
        throw Exception(
          'Descargue tallas y colores antes de operar sin conexión',
        );
      int selectedTallaId = tallas.first['id'] as int;
      int selectedColorId = colores.first['id'] as int;
      String selectedTallaNombre = tallas.first['nombre'] as String;
      String selectedColorNombre = colores.first['nombre'] as String;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            p['nombre'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bs ${p['precio'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Selecciona Talla:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tallas.map((t) {
                              final isSelected = selectedTallaId == t['id'];
                              return ChoiceChip(
                                label: Text(t['nombre'] as String),
                                selected: isSelected,
                                selectedColor: const Color(0xFFFFEDD5),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFEA580C)
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setStateModal(() {
                                      selectedTallaId = t['id'] as int;
                                      selectedTallaNombre =
                                          t['nombre'] as String;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Selecciona Color:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: colores.map((c) {
                              final isSelected = selectedColorId == c['id'];
                              return ChoiceChip(
                                label: Text(c['nombre'] as String),
                                selected: isSelected,
                                selectedColor: const Color(0xFFFFEDD5),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFEA580C)
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setStateModal(() {
                                      selectedColorId = c['id'] as int;
                                      selectedColorNombre =
                                          c['nombre'] as String;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              CartService().addItem(
                                p['id'],
                                p['nombre'],
                                (p['precio'] as num).toDouble(),
                                tallaId: selectedTallaId,
                                tallaName: selectedTallaNombre,
                                colorId: selectedColorId,
                                colorName: selectedColorNombre,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Añadido a la bolsa'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: const Text(
                              'Añadir a la Bolsa',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tienda FashionStore',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Configurar IP Servidor',
            onPressed: _configurarServidor,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Catálogo',
            onPressed: _loadProductos,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF4F3EF),
      body: Column(
        children: [
          // Banner Informativo de Modo Offline (Req 5.3)
          if (isOfflineMode)
            Container(
              color: Colors.amber.shade900,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modo Offline (SQLite) — Los precios y stock pueden diferir del servidor central.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                  )
                : productos.isEmpty
                ? const Center(child: Text('No hay ropa en el catálogo.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final p = productos[index];

                      String? imgUrl = ApiService.resolveMediaUrl(p['imagen_url']?.toString());
                      String? url3d = ApiService.resolveMediaUrl(p['modelo_3d_url']?.toString());
                      final tieneAR = url3d.isNotEmpty;

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: imgUrl.isNotEmpty
                                      ? Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                        )
                                      : const Icon(
                                          Icons.image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['nombre'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bs ${p['precio'] ?? 0}',
                                    style: const TextStyle(
                                      color: Color(0xFFEA580C),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (tieneAR)
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFEA580C,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () =>
                                                _abrirAR(url3d, p['nombre']),
                                            child: const Text(
                                              'Ver 3D',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ),
                                      if (tieneAR) const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () =>
                                              _mostrarOpcionesProducto(p),
                                          child: const Text(
                                            '+ Agregar',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
