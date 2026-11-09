import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_db_service.dart';
import 'cart_service.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class ApiService {
  // Configuración de URL base (127.0.0.1 funciona directo por USB con adb reverse en Android Studio)
  static String baseUrl = 'http://127.0.0.1:8000/api/v1';

  static Future<void> initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty && !savedUrl.contains('10.0.2.2')) {
      baseUrl = savedUrl;
    } else {
      baseUrl = 'http://127.0.0.1:8000/api/v1';
      await prefs.setString('custom_base_url', baseUrl);
    }
  }

  static Future<void> setBaseUrl(String newUrl) async {
    baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', newUrl);
  }

  /// Resuelve URLs relativas o con localhost a la dirección accesible por el dispositivo móvil
  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final baseUri = Uri.parse(baseUrl);
      final origin = '${baseUri.scheme}://${baseUri.authority}';
      if (url.startsWith('/')) {
        return '$origin$url';
      }
      if (url.contains('localhost')) {
        return url
            .replaceAll('localhost:8000', baseUri.authority)
            .replaceAll('localhost', baseUri.host);
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  Future<Map<String, dynamic>?> registrarCliente(
    String nombre,
    String email,
    String password, {
    int empresaId = 1,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seguridad/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre_completo': nombre,
        'email': email,
        'password': password,
        'rol_id': 4, // ID 4 = Cliente
        'empresa_id': empresaId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['detail'] ?? 'Error desconocido',
      );
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seguridad/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token']);
      return data;
    } else {
      throw Exception(
        jsonDecode(response.body)['detail'] ?? 'Error desconocido',
      );
    }
  }

  // --- PERSISTENCIA Y SESIÓN ---
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    CartService().clear();
  }

  Map<String, dynamic> decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = parts[1];
    final String normalized = base64Url.normalize(payload);
    final String resp = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(resp);
  }

  Future<void> changePassword(int userId, String newPassword) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/seguridad/change-password'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'user_id': userId, 'new_password': newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        jsonDecode(response.body)['detail'] ?? 'Error al cambiar contraseña',
      );
    }
  }

  // --- CATÁLOGO ---
  Future<List<dynamic>> getProductos({int? empresaId}) async {
    String url = '$baseUrl/catalogo/productos/';
    if (empresaId != null) {
      url += '?empresa_id=$empresaId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se pudo cargar el catálogo');
    }
  }

  Future<List<dynamic>> getColores() async {
    final response = await http.get(
      Uri.parse('$baseUrl/catalogo/colores/'),
      headers: await authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se pudo cargar colores');
    }
  }

  Future<List<dynamic>> getTallas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/catalogo/tallas/'),
      headers: await authHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se pudo cargar tallas');
    }
  }

  // --- SUCURSALES ---
  Future<List<dynamic>> getSucursales({int? empresaId}) async {
    String url = '$baseUrl/sucursales/sucursales';
    if (empresaId != null) {
      url += '?empresa_id=$empresaId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('No se pudieron cargar las sucursales');
    }
  }

  // --- VENTAS Y RESERVAS DIRECTAS ---
  Future<void> crearReserva(
    List<dynamic> items,
    int sucursalId, {
    String? operacionUuid,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No hay sesión activa.');

    final decoded = decodeJwt(token);
    final userId = decoded['id'];

    final body = {
      'sucursal_id': sucursalId,
      'operacion_uuid': operacionUuid,
      'usuario_id': userId,
      'detalles': items
          .map(
            (item) => {
              'producto_id': item.productoId,
              'talla_id': item.tallaId,
              'color_id': item.colorId,
              'cantidad': item.cantidad,
              'precio_unitario': item.precioUnitario,
            },
          )
          .toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/reservas/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        (jsonDecode(response.body)['detail'] ?? 'Error al crear reserva')
            .toString(),
        response.statusCode,
      );
    }
  }

  Future<void> crearVenta(
    List<dynamic> items,
    String tipoEntrega,
    String direccionEnvio,
    String metodoPago, {
    int? sucursalId,
    String? cuponCodigo,
    String? operacionUuid,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No hay sesión activa.');

    final decoded = decodeJwt(token);
    final userId = decoded['id'];

    final body = {
      'sucursal_id': sucursalId,
      'operacion_uuid': operacionUuid,
      'cupon_codigo': cuponCodigo,
      'usuario_id': userId,
      'metodo_pago': metodoPago,
      'transaccion_id': null,
      'tipo_entrega': tipoEntrega,
      'direccion_envio': direccionEnvio,
      'detalles': items
          .map(
            (item) => {
              'producto_id': item.productoId,
              'talla_id': item.tallaId,
              'color_id': item.colorId,
              'cantidad': item.cantidad,
              'precio_unitario': item.precioUnitario,
            },
          )
          .toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/ventas/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        (jsonDecode(response.body)['detail'] ?? 'Error al crear la venta')
            .toString(),
        response.statusCode,
      );
    }
  }

  // ===========================================================================
  // PROTOCOLO DE SINCRONIZACIÓN OFFLINE EN LOTE (Desafíos III & IV)
  // ===========================================================================

  Future<Map<String, dynamic>> sincronizarVentasLote(
    List<Map<String, dynamic>> operaciones,
  ) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({'ventas': operaciones});

    final response = await http.post(
      Uri.parse('$baseUrl/ventas/sincronizar-offline'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['detail'] ??
            'Error en sincronización de ventas',
      );
    }
  }

  Future<Map<String, dynamic>> sincronizarReservasLote(
    List<Map<String, dynamic>> operaciones,
  ) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({'reservas': operaciones});

    final response = await http.post(
      Uri.parse('$baseUrl/reservas/sincronizar-offline'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['detail'] ??
            'Error en sincronización de reservas',
      );
    }
  }

  Future<int> getEmpresaId() async {
    final token = await getToken();
    if (token == null) return 1;
    final payload = decodeJwt(token);
    final empId = payload['empresa_id'];
    if (empId is int) return empId;
    if (empId is String) return int.tryParse(empId) ?? 1;
    return 1;
  }

  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> getJson(String path) async {
    final r = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await authHeaders(),
    );
    if (r.statusCode != 200)
      throw ApiException(
        (jsonDecode(r.body)['detail'] ?? 'Error al consultar').toString(),
        r.statusCode,
      );
    return jsonDecode(r.body);
  }

  Future<dynamic> postJson(String path, dynamic data) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await authHeaders(),
      body: jsonEncode(data),
    );
    if (r.statusCode >= 400)
      throw ApiException(
        (jsonDecode(r.body)['detail'] ?? 'Error al guardar').toString(),
        r.statusCode,
      );
    return jsonDecode(r.body);
  }

  Future<List<dynamic>> referencias(String type) async {
    try {
      final data = await getJson('/catalogo/$type') as List<dynamic>;
      await OfflineDbService().guardarReferencia(type, data);
      return data;
    } catch (e) {
      if (e is ApiException) rethrow;
      return OfflineDbService().getReferencia(type);
    }
  }
}
