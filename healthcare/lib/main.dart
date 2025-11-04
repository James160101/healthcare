import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/real_time_monitor.dart';
import 'screens/alerts_screen.dart'; // Ajout de l'import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FirebaseService(),
      child: MaterialApp(
        title: 'Surveillance Cardiaque',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        home: const AuthWrapper(), 
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/history': (context) => const HistoryScreen(),
          '/monitor': (context) => const RealTimeMonitor(),
          '/alerts': (context) => const AlertsScreen(), // Ajout de la route
        },
      ),
    );
  }
}
