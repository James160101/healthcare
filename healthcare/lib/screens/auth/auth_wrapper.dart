import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import 'login_screen.dart';
import '../main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
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
          return const MainScreen(); // Si l'utilisateur est connecté, aller à l'écran principal
        }

        return const LoginScreen(); // Sinon, afficher l'écran de connexion
      },
    );
  }
}
