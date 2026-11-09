import 'package:flutter/material.dart';

import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';

class VestidorScreen extends StatefulWidget {
  const VestidorScreen({super.key});

  @override
  State<VestidorScreen> createState() => _VestidorScreenState();
}

class _VestidorScreenState extends State<VestidorScreen> {
  final ApiService _api = ApiService();
  File? _userImage;
  List<dynamic> _productos = [];
  dynamic _selectedProduct;
  bool _isLoading = true;

  Offset _position = const Offset(100, 100);
  double _scale = 1.0;
  double _rotation = 0.0;
  double _baseScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    try {
      final data = await _api.getProductos();
      setState(() {
        _productos = data.where((p) => p['imagen_url'] != null).map((p) {
          if (p['imagen_url'] != null) {
            String rawUrl = ApiService.resolveMediaUrl(p['imagen_url'].toString());
            p['imagen_url'] =
                '${ApiService.baseUrl}/archivos/proxy-nobg?url=${Uri.encodeComponent(rawUrl)}';
          }
          return p;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _userImage = File(image.path);
        _position = const Offset(100, 100);
        _scale = 1.0;
        _rotation = 0.0;
      });
    }
  }

  void _mostrarOpcionesProducto() async {
    try {
      final colores = await _api.getColores();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elige el color para ${_selectedProduct['nombre']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: colores.map((c) {
                    return ActionChip(
                      label: Text(c['nombre']),
                      onPressed: () {
                        Navigator.pop(context);
                        CartService().addItem(
                          _selectedProduct['id'],
                          _selectedProduct['nombre'],
                          (_selectedProduct['precio'] ?? 0).toDouble(),
                          colorId: c['id'],
                          colorName: c['nombre'],
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_selectedProduct['nombre']} (${c['nombre']}) añadido a tus reservas',
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cargar colores: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vestidor IA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _userImage == null
                        ? 'Subir Foto de Cuerpo Completo'
                        : 'Cambiar Foto',
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<dynamic>(
                    value: _selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Selecciona una Prenda',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items: _productos.map<DropdownMenuItem<dynamic>>((p) {
                      return DropdownMenuItem<dynamic>(
                        value: p,
                        child: Text(p['nombre']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedProduct = val),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: _userImage == null
                  ? const Center(
                      child: Text(
                        'Sube tu foto para empezar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.file(_userImage!, fit: BoxFit.contain),
                          ),
                          if (_selectedProduct != null &&
                              _selectedProduct['imagen_url'] != null)
                            Positioned(
                              left: _position.dx,
                              top: _position.dy,
                              child: GestureDetector(
                                onScaleStart: (details) {
                                  _baseScaleFactor = _scale;
                                },
                                onScaleUpdate: (details) {
                                  setState(() {
                                    _position += details.focalPointDelta;
                                    _scale = _baseScaleFactor * details.scale;
                                    _rotation = details.rotation;
                                  });
                                },
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..scale(_scale)
                                    ..rotateZ(_rotation),
                                  child: Image.network(
                                    _selectedProduct['imagen_url'],
                                    width: 200, // Tamaño inicial
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.broken_image,
                                      size: 100,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (_selectedProduct != null)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Pellizca para cambiar tamaño o rotar. Arrastra para mover.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),

          if (_userImage != null && _selectedProduct != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _mostrarOpcionesProducto();
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text(
                    'Me encanta, añadir a la bolsa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
