import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import pour l'initialisation des locales
import '../services/firebase_service.dart';
import '../models/alert.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialisation des données de localisation pour le français
    initializeDateFormatting('fr_FR', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre d\'Alertes'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text('Aucune alerte pour ce patient', style: TextStyle(fontSize: 16)),
                  Text('Tout est sous contrôle.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: service.alerts.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final alert = service.alerts[index];
              final isCritical = alert.level == AlertLevel.Critical;

              final color = isCritical ? Colors.red.shade800 : Colors.orange.shade800;
              final bgColor = isCritical ? Colors.red.shade100 : Colors.orange.shade100;
              final icon = isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isCritical ? 'ALERTE CRITIQUE' : 'AVERTISSEMENT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm', 'fr_FR').format(alert.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${alert.type}: ${alert.message}',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        // Utilisation de la locale française pour le formatage
                        DateFormat('EEEE d MMMM y', 'fr_FR').format(alert.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
