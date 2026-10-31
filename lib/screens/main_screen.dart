import 'package:flutter/material.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'vestidor_screen.dart';
import 'offline_sync_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const CatalogScreen(),
    const VestidorScreen(),
    const CartScreen(),
    const OfflineSyncScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFEA580C),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Asegura que se vean todos los íconos
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Vestidor IA',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_sync_outlined),
            activeIcon: Icon(Icons.cloud_sync),
            label: 'SQLite Sync',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
