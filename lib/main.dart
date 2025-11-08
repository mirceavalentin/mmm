import 'package:flutter/material.dart';
import 'package:task_manager_app/home_page.dart';
import 'package:task_manager_app/login_page.dart';
import 'package:task_manager_app/storage_service.dart';
import 'package:task_manager_app/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
      home: _AppInitializer(), // NOU: Folosim un "splash screen" logic
    );
  }
}

// NOU: Un widget care decide unde să trimită utilizatorul la pornire
class _AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) {
      // Nu e logat, mergem la Login
      _navigateTo(const LoginPage());
      return;
    }

    // Avem un refresh token, încercăm să reînnoim
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        // Reînnoire cu succes!
        final data = jsonDecode(response.body);
        final String accessToken = data['accessToken'];
        final String newRefreshToken =
            data['refreshToken']; // Serverul poate reîmprospăta și refresh token-ul

        // Salvăm noile token-uri
        await _storageService.saveTokens(accessToken, newRefreshToken);

        // Aici avem o problemă: nu avem `username`.
        // Trebuie să-l fi salvat și pe el, sau să facem un apel la /auth/me
        // Pentru simplitate, deocamdată trimitem un "User" placeholder
        // Ideal, /auth/refresh ar returna și obiectul 'user'
        _navigateTo(const HomePage(username: 'Agent'));
      } else {
        // Refresh token-ul e invalid
        await _storageService.clearTokens();
        _navigateTo(const LoginPage());
      }
    } catch (e) {
      // Fără rețea, etc.
      _navigateTo(const LoginPage());
    }
  }

  void _navigateTo(Widget page) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un splash screen simplu
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.red)),
    );
  }
}
