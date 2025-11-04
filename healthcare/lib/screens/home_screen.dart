import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/patient_data.dart';
import '../models/doctor.dart';
import '../widgets/app_drawer.dart'; // Import du nouveau widget
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context);
    final Doctor? doctor = service.currentDoctor;

    return Scaffold(
      // Ajout du Drawer
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(doctor?.name ?? 'Surveillance'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return _buildWaitingState("Chargement des données...");
          }
          
          if (service.error != null) {
            return _buildErrorState(service.error!);
          }

          if (service.historyData.isEmpty) {
            return _buildWaitingState("En attente de la première mesure...");
          }
          
          final latest = service.latestData;

          return RefreshIndicator(
            onRefresh: () => service.loadHistory(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPatientCard(service.patientId ?? 'Patient Inconnu'),
                  const SizedBox(height: 16),

                  if (latest != null) ...[
                    _buildVitalSignsCard(latest),
                    const SizedBox(height: 16),
                    _buildStatusCard(latest),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(service),
                  ] else
                    _buildNoDataCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientCard(String patientId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 32, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientId,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Surveillance en temps réel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildVitalSignsCard(PatientData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Signes Vitaux',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('HH:mm:ss').format(data.timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildVitalSignItem(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    label: 'Fréquence Cardiaque',
                    value: '${data.heartRate}',
                    unit: 'BPM',
                    status: data.heartRateStatus,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildVitalSignItem(
                    icon: Icons.water_drop,
                    iconColor: Colors.blue,
                    label: 'Saturation O2',
                    value: data.spo2.toStringAsFixed(1),
                    unit: '%',
                    status: data.spo2Status,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String status,
  }) {
    Color statusColor;
    if (status == 'Normal') {
      statusColor = Colors.green;
    } else if (status == 'Attention' || status == 'Faible') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildStatusCard(PatientData data) {
    Color statusColor = data.isNormal ? Colors.green : Colors.orange;
    if (data.isCritical) statusColor = Colors.red;

    IconData statusIcon = data.isNormal
        ? Icons.check_circle
        : (data.isCritical ? Icons.warning : Icons.info);

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'État: ${data.status}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.isCritical
                        ? 'Attention requise immédiatement'
                        : data.isNormal
                        ? 'Tous les paramètres sont normaux'
                        : 'Surveillance recommandée',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(FirebaseService service) {
    final stats = service.getStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques (Dernières mesures)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Fréquence cardiaque moyenne',
              '${stats['avgHeartRate']} BPM',
            ),
            _buildStatRow(
              'Plage FC',
              '${stats['minHeartRate']} - ${stats['maxHeartRate']} BPM',
            ),
            _buildStatRow(
              'SpO2 moyenne',
              '${stats['avgSpo2'].toStringAsFixed(1)}%',
            ),
            _buildStatRow(
              'Plage SpO2',
              '${stats['minSpo2'].toStringAsFixed(1)}% - ${stats['maxSpo2'].toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<FirebaseService>().loadHistory();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.sensors_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'En attente de données...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vérifiez que le capteur est connecté',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
