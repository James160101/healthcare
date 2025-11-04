import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import 'login_screen.dart';
import '../home_screen.dart'; // Votre écran principal

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return StreamBuilder<User?>(
      stream: firebaseService.authStateChanges,
      builder: (context, snapshot) {
        // En attente de vérification
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Utilisateur connecté
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); // Votre écran d'accueil
        }

        // Utilisateur non connecté
        return const LoginScreen();
      },
    );
  }
}
