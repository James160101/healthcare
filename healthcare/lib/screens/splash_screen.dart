import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/heartbeat_loader.dart';
import 'auth/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Timer de 3 secondes avant de naviguer
    Timer(const Duration(seconds: 3), () {
      // Remplacer l'écran actuel par AuthWrapper (gestionnaire de connexion)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou Titre
            const Text(
              "HealthCare",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Surveillance Cardiaque",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 60),
            // Notre animation cardiaque
            const HeartbeatLoader(
              size: 100,
              color: Colors.redAccent,
              message: "Chargement...",
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
