import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/patient_data.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Helper function to clamp values to a reasonable range for display
  double _clampValue(double value, double min, double max) {
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.historyData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Aucune donnée d\'historique disponible', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Heart Rate Chart
                _buildHistoryChart(
                  title: 'Historique de la Fréquence Cardiaque',
                  history: service.historyData,
                  dataExtractor: (data) => _clampValue(data.heartRate.toDouble(), 40, 180), // Clamping BPM
                  color: Colors.red,
                  minY: 40,
                  maxY: 180,
                  unit: 'BPM',
                ),
                const SizedBox(height: 32),

                // SpO2 Chart
                _buildHistoryChart(
                  title: 'Historique de la Saturation O2',
                  history: service.historyData,
                  dataExtractor: (data) => _clampValue(data.spo2, 80, 100), // Clamping SpO2
                  color: Colors.blue,
                  minY: 80,
                  maxY: 100,
                  unit: '%',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Generic Widget for a history chart
  Widget _buildHistoryChart({
    required String title,
    required List<PatientData> history,
    required double Function(PatientData) dataExtractor,
    required Color color,
    required double minY,
    required double maxY,
    required String unit,
  }) {
    // On prend l'historique complet, pas seulement les 60 dernières secondes
    final chartData = history.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 250, // Graphique plus grand
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                // Y-axis labels
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) =>
                        Text('${value.toInt()}$unit', style: const TextStyle(fontSize: 10)),
                  ),
                ),
                // X-axis labels
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (chartData.length / 4).ceilToDouble(), // Moins de labels sur l'axe X
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                        final time = chartData[value.toInt()].timestamp;
                        return Text(DateFormat('HH:mm').format(time), style: const TextStyle(fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.5))),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < chartData.length; i++)
                      FlSpot(i.toDouble(), dataExtractor(chartData[i]))
                  ],
                  isCurved: true,
                  color: color,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
