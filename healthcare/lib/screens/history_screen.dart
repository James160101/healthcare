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
  HistoryRange _selectedRange = HistoryRange.all;

  double _clampValue(double value, double min, double max) {
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final patientName = service.patientId != null ? service.getPatientById(service.patientId!)?.name : null;

    return Scaffold(
      appBar: AppBar(title: Text(patientName != null ? 'Historique de $patientName' : 'Historique')),
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

          return Column(
            children: [
              _buildFilterButtons(service),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHistoryChart(title: 'Fréquence Cardiaque', history: service.historyData, dataExtractor: (data) => _clampValue(data.heartRate.toDouble(), 40, 180), color: Colors.red, minY: 40, maxY: 180, unit: 'BPM'),
                      const SizedBox(height: 32),
                      _buildHistoryChart(title: 'Saturation O2', history: service.historyData, dataExtractor: (data) => _clampValue(data.spo2, 80, 100), color: Colors.blue, minY: 80, maxY: 100, unit: '%'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterButtons(FirebaseService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFilterChip('Jour', HistoryRange.day, service),
          _buildFilterChip('Semaine', HistoryRange.week, service),
          _buildFilterChip('Mois', HistoryRange.month, service),
          _buildFilterChip('Tout', HistoryRange.all, service),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, HistoryRange range, FirebaseService service) {
    final isSelected = _selectedRange == range;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRange = range;
          });
          service.filterHistoryByRange(range);
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildHistoryChart({required String title, required List<PatientData> history, required double Function(PatientData) dataExtractor, required Color color, required double minY, required double maxY, required String unit}) {
    final chartData = history.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(show: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1), drawVerticalLine: false),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('${value.toInt()}$unit', style: const TextStyle(fontSize: 10)))),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 22, interval: (chartData.length / 4).ceilToDouble(),
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
                  spots: [for (int i = 0; i < chartData.length; i++) FlSpot(i.toDouble(), dataExtractor(chartData[i]))],
                  isCurved: true, color: color, barWidth: 2.5, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
