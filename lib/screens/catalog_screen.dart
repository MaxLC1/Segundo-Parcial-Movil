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
            content: Text('Sin conexión al servidor. Cargando catálogo guardado en SQLite local.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar catálogo y no hay datos offline: $e')),
        );
        setState(() => isLoading = false);
      }
    }
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
        builder: (context) => ARScreen(
          url3d: url3d,
          nombreProducto: nombreProducto,
        ),
      ),
    );
  }

  void _mostrarOpcionesProducto(dynamic p) async {
    try {
      final tallas = [
        {'id': 1, 'nombre': 'S'},
        {'id': 2, 'nombre': 'M'},
        {'id': 3, 'nombre': 'L'},
        {'id': 4, 'nombre': 'XL'}
      ];
      final colores = [
        {'id': 1, 'nombre': 'Negro'},
        {'id': 2, 'nombre': 'Blanco'},
        {'id': 3, 'nombre': 'Azul'},
        {'id': 4, 'nombre': 'Rojo'}
      ];

      int selectedTallaId = tallas.first['id'] as int;
      int selectedColorId = colores.first['id'] as int;
      String selectedTallaNombre = tallas.first['nombre'] as String;
      String selectedColorNombre = colores.first['nombre'] as String;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateModal) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(p['nombre'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Bs ${p['precio'] ?? 0}', style: const TextStyle(fontSize: 18, color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    const Text('Selecciona Talla:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: tallas.map((t) {
                        final isSelected = selectedTallaId == t['id'];
                        return ChoiceChip(
                          label: Text(t['nombre'] as String),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setStateModal(() {
                                selectedTallaId = t['id'] as int;
                                selectedTallaNombre = t['nombre'] as String;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    const Text('Selecciona Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: colores.map((c) {
                        final isSelected = selectedColorId == c['id'];
                        return ChoiceChip(
                          label: Text(c['nombre'] as String),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setStateModal(() {
                                selectedColorId = c['id'] as int;
                                selectedColorNombre = c['nombre'] as String;
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        CartService().addItem(
                          productoId: p['id'],
                          nombre: p['nombre'],
                          precioUnitario: (p['precio'] as num).toDouble(),
                          imagenUrl: p['imagen_url'],
                          tallaId: selectedTallaId,
                          tallaNombre: selectedTallaNombre,
                          colorId: selectedColorId,
                          colorNombre: selectedColorNombre,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('¡Añadido a la bolsa!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Text('Añadir a la Bolsa', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          );
        }
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda FashionStore', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        actions: [
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
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                : productos.isEmpty
                    ? const Center(child: Text('No hay ropa en el catálogo.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final p = productos[index];
                          
                          String? imgUrl = p['imagen_url']?.toString();
                          String? url3d = p['modelo_3d_url']?.toString();
                          final tieneAR = url3d != null && url3d.isNotEmpty;

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: (imgUrl != null && imgUrl.isNotEmpty)
                                        ? Image.network(
                                            imgUrl, 
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                          )
                                        : const Icon(Icons.image, size: 50, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('Bs ${p['precio'] ?? 0}', style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (tieneAR)
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFEA580C),
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                onPressed: () => _abrirAR(url3d, p['nombre']),
                                                child: const Text('Ver 3D', style: TextStyle(fontSize: 11)),
                                              ),
                                            ),
                                          if (tieneAR) const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () => _mostrarOpcionesProducto(p),
                                              child: const Text('+ Agregar', style: TextStyle(fontSize: 11)),
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
