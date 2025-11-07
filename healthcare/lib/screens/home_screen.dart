import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Import pour les graphiques
import 'package:syncfusion_flutter_gauges/gauges.dart'; // Import pour la jauge
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

          if (service.patientId == null || service.historyData.isEmpty) {
            return _buildWaitingState(service.patientId == null 
                ? "Veuillez sélectionner un patient."
                : "En attente des données du patient...");
          }
          
          final history = service.historyData;
          final latest = service.latestData!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Graphique ECG / BPM
                _buildEcgChart(history),
                const SizedBox(height: 32),
                // Jauge SpO2
                SizedBox(
                  height: 250,
                  child: _buildSpo2Gauge(latest),
                ),
                const SizedBox(height: 32),
                // Ligne pour les valeurs temps réel de BPM et SpO2 avec statut
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildRealTimeValueText(
                          label: 'BPM',
                          value: latest.heartRate.toString(),
                          icon: Icons.favorite,
                          color: Colors.red,
                        ),
                        _buildRealTimeValueText(
                          label: 'SpO2',
                          value: '${latest.spo2.toStringAsFixed(0)} %',
                          icon: Icons.opacity, // Icône modifiée
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatusIndicator(latest.heartRateStatus),
                        _buildStatusIndicator(latest.spo2Status),
                      ],
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // Graphique de style ECG pour la fréquence cardiaque
  Widget _buildEcgChart(List<PatientData> history) {
    final recentHistory = history.take(60).toList().reversed.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fréquence cardiaque',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 40,
              maxY: 180,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: const TextStyle(fontSize: 10)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 20, getTitlesWidget: (value, meta) => Text('${value.toInt()}s', style: const TextStyle(fontSize: 10)))),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.5))),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < recentHistory.length; i++)
                      FlSpot(i.toDouble(), recentHistory[i].heartRate.toDouble())
                  ],
                  isCurved: false,
                  isStepLineChart: true,
                  color: Theme.of(context).colorScheme.primary, // Utilisation de la nouvelle couleur
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Jauge circulaire pour SpO2 - Style compteur de vitesse
  Widget _buildSpo2Gauge(PatientData data) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 80,
          maximum: 100,
          interval: 5, // Affiche un label tous les 5 points
          axisLabelStyle: const GaugeTextStyle(fontSize: 12),
          ranges: <GaugeRange>[
            GaugeRange(startValue: 80, endValue: 90, color: Colors.red.shade300),
            GaugeRange(startValue: 90, endValue: 95, color: Colors.orange.shade300),
            GaugeRange(startValue: 95, endValue: 100, color: Colors.green.shade300),
          ],
          pointers: <GaugePointer>[
            NeedlePointer( // Aiguille
              value: data.spo2,
              enableAnimation: true,
              animationType: AnimationType.ease,
              needleStartWidth: 1,
              needleEndWidth: 5,
              needleColor: Theme.of(context).colorScheme.onSurface,
              knobStyle: KnobStyle(
                knobRadius: 0.08,
                color: Theme.of(context).colorScheme.surface,
                borderColor: Theme.of(context).colorScheme.onSurface,
                borderWidth: 0.02,
              ),
            )
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SPO2',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  Text(
                    '${data.spo2.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.7, // Ajuste la position verticale de l'annotation
            )
          ],
        )
      ],
    );
  }

  // Widget pour afficher une valeur temps réel (BPM ou SpO2)
  Widget _buildRealTimeValueText({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: 24,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w300,
        ),
        children: [
          TextSpan(text: '$label : '),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(icon, color: color, size: 28),
            ),
            alignment: PlaceholderAlignment.middle,
          ),
        ],
      ),
    );
  }

  // Widget pour afficher un indicateur de statut (Normal, Faible, etc.)
  Widget _buildStatusIndicator(String status) {
    final isNormal = status == 'Normal';
    final color = isNormal ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20), // Forme de pilule
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
}
