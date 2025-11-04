import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/alert.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Alertes'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          // On suppose que le service a une liste 'alerts'
          // Il faudra l'ajouter au FirebaseService si elle n'existe pas
          final alerts = service.alerts;

          if (alerts.isEmpty) {
            return const Center(
              child: Text('Aucune alerte à afficher.'),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final color = alert.level == AlertLevel.Critical ? Colors.red.shade700 : Colors.orange.shade700;
              final icon = alert.level == AlertLevel.Critical ? Icons.warning : Icons.info_outline;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withOpacity(0.5), width: 1),
                ),
                child: ListTile(
                  leading: Icon(icon, color: color, size: 32),
                  title: Text(
                    alert.type,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  subtitle: Text(alert.message),
                  trailing: Text(
                    DateFormat('dd/MM\nHH:mm').format(alert.timestamp),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
