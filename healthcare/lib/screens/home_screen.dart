import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart'; // Import de la bibliothèque de jauges
import '../services/firebase_service.dart';
import '../models/patient_data.dart';
import '../models/doctor.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FirebaseService>(context, listen: false).selectPatient('PATIENT_001');
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context);
    final Doctor? doctor = service.currentDoctor;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(doctor?.name ?? 'Surveillance Patient'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return _buildWaitingState("Chargement des données...");
          }
          
          if (service.error != null) {
            return _buildErrorState(service.error!);
          }

          if (service.patientId == null) {
            return _buildWaitingState("Veuillez sélectionner un patient.");
          }

          if (service.historyData.isEmpty) {
            return _buildWaitingState("En attente des données du patient...");
          }
          
          final latest = service.latestData;

          return RefreshIndicator(
            onRefresh: () => service.loadHistory(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPatientCard(service.patientId!),
                  const SizedBox(height: 16),

                  if (latest != null) ...[
                    _buildVitalSignsGrid(latest), // Remplacement par une grille
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Surveillance en temps réel',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
            // On peut ajouter l'heure de la dernière mesure ici
            Consumer<FirebaseService>(
              builder: (context, service, child) {
                if (service.latestData == null) return const SizedBox.shrink();
                return Text(
                  DateFormat('HH:mm:ss').format(service.latestData!.timestamp),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Nouvelle méthode utilisant une grille pour les signes vitaux
  Widget _buildVitalSignsGrid(PatientData data) {
    return GridView.count(
      crossAxisCount: 2, // 2 éléments par ligne
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildHeartRateCard(data),
        _buildSpo2Gauge(data),
      ],
    );
  }
  
  // Widget pour la fréquence cardiaque (similaire à l'ancien _buildVitalSignItem)
  Widget _buildHeartRateCard(PatientData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite, color: Colors.red, size: 28),
          const SizedBox(height: 12),
          const Text('Fréquence Cardiaque', style: TextStyle(fontSize: 12)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${data.heartRate}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text('BPM'),
            ],
          ),
           const Spacer(),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: (data.heartRateStatus == 'Normal' ? Colors.green : Colors.orange).withOpacity(0.2),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Text(
               data.heartRateStatus,
               style: TextStyle(color: data.heartRateStatus == 'Normal' ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
             ),
           ),
        ],
      ),
    );
  }

  // Nouveau widget pour la jauge SpO2
  Widget _buildSpo2Gauge(PatientData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 80,
            maximum: 100,
            showLabels: false,
            showTicks: false,
            axisLineStyle: const AxisLineStyle(
              thickness: 0.2,
              cornerStyle: CornerStyle.bothCurve,
              thicknessUnit: GaugeSizeUnit.factor,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: data.spo2,
                width: 0.2,
                sizeUnit: GaugeSizeUnit.factor,
                cornerStyle: CornerStyle.bothCurve,
                gradient: const SweepGradient(
                  colors: <Color>[Colors.red, Colors.orange, Colors.green],
                  stops: <double>[0.25, 0.5, 0.75],
                ),
              ),
              MarkerPointer(
                value: data.spo2,
                markerType: MarkerType.circle,
                color: Colors.white,
                markerHeight: 15,
                markerWidth: 15,
                borderWidth: 2,
                borderColor: Colors.grey.shade500,
              )
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.air, color: Colors.blue, size: 28),
                     const SizedBox(height: 8),
                    Text(
                      '${data.spo2.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Text('SpO2', style: TextStyle(fontSize: 12)),
                  ],
                ),
                angle: 90,
                positionFactor: 0.1,
              )
            ],
          )
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.isCritical
                        ? 'Attention requise immédiatement'
                        : data.isNormal
                        ? 'Tous les paramètres sont normaux'
                        : 'Surveillance recommandée',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('FC Moyenne', '${stats['avgHeartRate']} BPM'),
            _buildStatRow('Plage FC', '${stats['minHeartRate']} - ${stats['maxHeartRate']} BPM'),
            _buildStatRow('SpO2 Moyenne', '${stats['avgSpo2'].toStringAsFixed(1)}%'),
            _buildStatRow('Plage SpO2', '${stats['minSpo2'].toStringAsFixed(1)}% - ${stats['maxSpo2'].toStringAsFixed(1)}%'),
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
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
            Text('Erreur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<FirebaseService>().loadHistory(),
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
              Text('En attente de données...', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text('Vérifiez que le capteur est bien connecté et envoie des données.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}
