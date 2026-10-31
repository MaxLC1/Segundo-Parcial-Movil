import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'register_screen.dart';

import 'delivery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  
  String correo = '';
  String password = '';
  bool isLoading = false;
  bool _obscurePassword = true;

  void _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => isLoading = true);
    
    try {
      final response = await _api.login(correo, password);
      if (response != null) {
        if (!mounted) return;
        
        final token = await _api.getToken();
        if (token != null) {
          final payload = _api.decodeJwt(token);
          
          if (payload['rol'] == 'Repartidor') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DeliveryScreen()),
            );
            return;
          }
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3EF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.checkroom, size: 80, color: Color(0xFFEA580C)),
              const SizedBox(height: 24),
              const Text(
                'Bienvenido de vuelta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text('Inicia sesión para ver tu catálogo AR', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
                      onSaved: (v) => correo = v!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => v!.isEmpty ? 'Ingresa tu contraseña' : null,
                      onSaved: (v) => password = v!,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isLoading ? null : _iniciarSesion,
                        child: isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Iniciar Sesión', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text('¿No tienes cuenta? Regístrate aquí', style: TextStyle(color: Color(0xFFEA580C))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
