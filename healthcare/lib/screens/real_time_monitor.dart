import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart'; // Assurez-vous que fl_chart est importé
import '../services/firebase_service.dart';
import '../models/patient_data.dart';
import '../widgets/vital_card.dart';

class RealTimeMonitor extends StatefulWidget {
  const RealTimeMonitor({super.key});

  @override
  State<RealTimeMonitor> createState() => _RealTimeMonitorState();
}

class _RealTimeMonitorState extends State<RealTimeMonitor>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(PatientData data) {
    if (data.isCritical) return Colors.red;
    if (!data.isNormal) return Colors.orange;
    return Colors.green;
  }

  String _getTimeSinceUpdate(DateTime lastUpdate) {
    final duration = DateTime.now().difference(lastUpdate);
    if (duration.inSeconds < 2) return 'à l\'instant';
    if (duration.inSeconds < 60) return 'il y a ${duration.inSeconds} sec';
    if (duration.inMinutes < 60) return 'il y a ${duration.inMinutes} min';
    return 'il y a ${duration.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Temps Réel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FirebaseService>().loadHistory(),
          ),
        ],
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return _buildWaitingState("Chargement...");
          }
          if (service.error != null) {
            return _buildErrorState(service.error!);
          }
          if (service.historyData.isEmpty) {
            return _buildWaitingState("En attente de données...");
          }

          final latest = service.latestData!;

          return RefreshIndicator(
            onRefresh: () => service.loadHistory(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildAnimatedHeader(latest),
                  _buildVitalCards(latest),
                  _buildTrendsChart(service.historyData), // Le nouveau graphique
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedHeader(PatientData data) {
    final statusColor = _getStatusColor(data);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: Icon(Icons.favorite, size: 60, color: statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.status,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor),
          ),
          const SizedBox(height: 8),
          Text(
            _getTimeSinceUpdate(data.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            DateFormat('HH:mm:ss - dd/MM/yyyy').format(data.timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCards(PatientData data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: VitalCard(icon: Icons.favorite, iconColor: Colors.red, label: 'Fréquence Cardiaque', value: data.heartRate.toString(), unit: 'BPM', status: data.heartRateStatus, statusColor: data.heartRateStatus == 'Normal' ? Colors.green : Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: VitalCard(icon: Icons.opacity, iconColor: Colors.blue, label: 'Saturation O₂', value: data.spo2.toStringAsFixed(1), unit: '%', status: data.spo2Status, statusColor: data.spo2Status == 'Normal' ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildIndicatorCard('Plage Normale BPM', '60-100', Icons.trending_flat, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildIndicatorCard('Plage Normale SpO₂', '95-100%', Icons.trending_up, Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nouveau graphique des tendances en barres
  Widget _buildTrendsChart(List<PatientData> history) {
    final recentData = history.take(20).toList().reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tendances (20 dernières mesures)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 180, // Limite supérieure pour le BPM
                    minY: 40,   // Limite inférieure pour le BPM
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    barGroups: recentData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final isCritical = data.heartRate < 60 || data.heartRate > 100;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: data.heartRate.toDouble(),
                            color: isCritical ? Colors.redAccent : Colors.greenAccent,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState(String message) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
        ]),
      ),
    );
  }
}
