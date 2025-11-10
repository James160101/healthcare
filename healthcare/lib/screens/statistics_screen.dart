import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/patient.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final patientId = service.patientId;

    if (patientId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistiques')),
        body: const Center(
          child: Text('Veuillez d\'abord sélectionner un patient sur l\'écran d\'accueil.'),
        ),
      );
    }

    // Utiliser la nouvelle méthode robuste
    final Patient? patient = service.getPatientById(patientId);

    final stats = service.getStatistics();

    return Scaffold(
      appBar: AppBar(title: Text('Stats de ${patient?.name ?? "Patient"}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatCard(
              title: 'Rythme Cardiaque (BPM)',
              avg: stats['avgBpm'].toString(),
              min: stats['minBpm'].toString(),
              max: stats['maxBpm'].toString(),
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'Saturation en Oxygène (SpO2)',
              avg: '${stats['avgSpo2'].toStringAsFixed(1)} %',
              min: '${stats['minSpo2'].toStringAsFixed(1)} %',
              max: '${stats['maxSpo2'].toStringAsFixed(1)} %',
              color: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String avg, required String min, required String max, required Color color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const Divider(height: 20, thickness: 1),
            _buildStatRow('Moyenne', avg),
            _buildStatRow('Minimum', min),
            _buildStatRow('Maximum', max),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
