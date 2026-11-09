import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_flutter_ar/services/api_service.dart';
import 'package:mobile_flutter_ar/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'});
    CartService().clear();
  });
  test(
    'Sale sync sends the backend contract and preserves server outcomes',
    () async {
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.sincronizarVentasLote([
          {'operacion_uuid': 'test-id', 'empresa_id': 2},
        ]),
        () => MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body.containsKey('ventas'), true);
          expect(body.containsKey('operaciones'), false);
          expect(body['ventas'][0]['empresa_id'], 2);
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'resultados': [
                {
                  'operacion_uuid': 'test-id',
                  'estado': 'CONFIRMADA',
                  'mensaje': 'ok',
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(result['resultados'][0]['estado'], 'CONFIRMADA');
    },
  );
  test(
    'Reservation sync uses reservas and rejects a failed server response',
    () async {
      await expectLater(
        http.runWithClient(
          () => ApiService().sincronizarReservasLote([
            {'operacion_uuid': 'test-id'},
          ]),
          () => MockClient((request) async {
            expect(jsonDecode(request.body).containsKey('reservas'), true);
            return http.Response('{"detail":"Servicio no disponible"}', 503);
          }),
        ),
        throwsException,
      );
    },
  );
  test('Cart separates product variants and computes their total', () {
    final cart = CartService();
    cart.addItem(1, 'Prenda', 100, tallaId: 1, colorId: 1);
    cart.addItem(1, 'Prenda', 100, tallaId: 1, colorId: 1);
    cart.addItem(1, 'Prenda', 100, tallaId: 2, colorId: 1);
    expect(cart.items.length, 2);
    expect(cart.items.first.cantidad, 2);
    expect(cart.total, 300);
  });
  test('Logout removes the token and clears the customer cart', () async {
    CartService().addItem(1, 'Prenda', 100);
    await ApiService().logout();
    expect(await ApiService().getToken(), isNull);
    expect(CartService().items, isEmpty);
  });
}
