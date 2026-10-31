import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ARScreen extends StatefulWidget {
  final String url3d;
  final String nombreProducto;

  const ARScreen({
    super.key,
    required this.url3d,
    required this.nombreProducto,
  });

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AR: ${widget.nombreProducto}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Visor 3D Interactivo y AR
          Positioned.fill(
            child: ModelViewer(
              src: widget.url3d,
              alt: "Un modelo 3D de ${widget.nombreProducto}",
              ar: true,
              arModes: const ['scene-viewer', 'webxr', 'quick-look'],
              autoRotate: true,
              cameraControls: true,
              iosSrc: widget.url3d,
              disableZoom: false,
            ),
          ),
          
          // Indicador para el usuario
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.swipe, color: Color(0xFFEA580C)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Toca y arrastra para rotar el modelo. Usa el botón AR para proyectarlo en tu espacio.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
