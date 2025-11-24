import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart'; // Import pour lancer appels/SMS
import '../services/firebase_service.dart';
import '../models/alert.dart';
import '../models/patient.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
  }

  // Fonction pour lancer un appel
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de lancer l'appel.")),
        );
      }
    }
  }

  // Fonction pour envoyer un SMS
  Future<void> _sendSms(String phoneNumber, String body) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': body}, // Texte pré-rempli
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir l'application SMS.")),
        );
      }
    }
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

          // Récupérer les infos du patient actuel pour avoir les numéros
          final Patient? currentPatient = service.getPatientById(service.patientId ?? '');

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
                    const SizedBox(height: 16),
                    
                    // --- BOUTONS D'URGENCE ---
                    if (currentPatient != null) 
                      Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Bouton Appel Patient
                              if (currentPatient.phone.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(currentPatient.phone),
                                  icon: const Icon(Icons.call, size: 20),
                                  label: const Text("Patient"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),

                              // Bouton Appel Famille
                              if (currentPatient.familyContact.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(currentPatient.familyContact),
                                  icon: const Icon(Icons.family_restroom, size: 20),
                                  label: const Text("Famille"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                
                              // Bouton SMS Urgence
                              if (currentPatient.familyContact.isNotEmpty)
                                IconButton(
                                  onPressed: () => _sendSms(
                                    currentPatient.familyContact, 
                                    "URGENCE - Hôpital: Le patient ${currentPatient.name} présente une anomalie (${alert.type}). Merci de nous contacter."
                                  ),
                                  icon: const Icon(Icons.message),
                                  color: Colors.orange.shade800,
                                  tooltip: "Envoyer SMS Famille",
                                ),
                            ],
                          ),
                        ],
                      ),
                      
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
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
