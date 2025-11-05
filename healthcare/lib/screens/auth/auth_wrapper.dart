import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Ajout de l'import Provider
import '../../services/firebase_service.dart';
import 'login_screen.dart';
import '../main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Correction: Utilisation de l'instance de FirebaseService fournie par Provider
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: firebaseService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen(); // Redirige vers MainScreen
        }

        return const LoginScreen();
      },
    );
  }
}
