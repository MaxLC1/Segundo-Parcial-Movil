import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _entregas = [];

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final token = await _api.getToken();
      if (token == null) {
        _irALogin();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/delivery/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _entregas = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar entregas');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateEstado(int id, String nuevoEstado) async {
    try {
      final token = await _api.getToken();
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/delivery/$id/estado'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'estado': nuevoEstado}),
      );
      
      if (response.statusCode == 200) {
        _fetchDeliveries();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Estado actualizado exitosamente'), backgroundColor: Colors.green),
           );
        }
      } else {
         throw Exception('Error al actualizar estado');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  void _irALogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _cerrarSesion() async {
    await _api.logout();
    _irALogin();
  }

  void _mostrarOpciones(int id, String estadoActual) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Actualizar Estado', style: TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                leading: const Icon(Icons.directions_bike),
                title: const Text('En Camino a Recoger'),
                onTap: () {
                  Navigator.pop(context);
                  _updateEstado(id, 'En Camino');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Recogido (Con el Repartidor)'),
                onTap: () {
                  Navigator.pop(context);
                  _updateEstado(id, 'Recogido');
                },
              ),
              ListTile(
                leading: const Icon(Icons.store),
                title: const Text('Entregado a Tienda (Completado)'),
                onTap: () {
                  Navigator.pop(context);
                  _updateEstado(id, 'Completado');
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Repartidor'),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDeliveries,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          )
        ],
      ),
      backgroundColor: const Color(0xFFF4F3EF),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : _entregas.isEmpty
              ? const Center(child: Text('No tienes recojos asignados en este momento.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entregas.length,
                  itemBuilder: (context, index) {
                    final entrega = _entregas[index];
                    Color estadoColor;
                    switch(entrega['estado']) {
                      case 'Completado': estadoColor = Colors.green; break;
                      case 'En Camino': estadoColor = Colors.orange; break;
                      case 'Recogido': estadoColor = Colors.blue; break;
                      default: estadoColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Devolución #${entrega['devolucion_id']}', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Chip(
                                  label: Text(entrega['estado'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  backgroundColor: estadoColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('ID Servicio Delivery: ${entrega['id']}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            if (entrega['estado'] != 'Completado')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.local_shipping),
                                  label: const Text('Actualizar Estado'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F2937),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _mostrarOpciones(entrega['id'], entrega['estado']),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
