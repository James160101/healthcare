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
  int _selectedPeriod = 0; // 0: Dernières 24h, 1: 7 jours, 2: 30 jours

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final historyData = service.historyData;

          if (historyData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune donnée disponible',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Selector
                _buildPeriodSelector(),
                const SizedBox(height: 20),

                // Heart Rate Chart
                const Text(
                  'Fréquence Cardiaque',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHeartRateChart(historyData),
                const SizedBox(height: 24),

                // SpO2 Chart
                const Text(
                  'Saturation en Oxygène (SpO2)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSpO2Chart(historyData),
                const SizedBox(height: 24),

                // Data List
                const Text(
                  'Mesures Récentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDataList(historyData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _buildPeriodButton('24h', 0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPeriodButton('7 jours', 1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPeriodButton('30 jours', 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = index;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(label),
    );
  }

  Widget _buildHeartRateChart(List<PatientData> data) {
    final filteredData = _filterDataByPeriod(data);

    if (filteredData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Pas de données pour cette période')),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 20,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 &&
                          value.toInt() < filteredData.length) {
                        final time = filteredData[value.toInt()].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('HH:mm').format(time),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    interval: (filteredData.length / 5).ceilToDouble(),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              minY: 40,
              maxY: 140,
              lineBarsData: [
                LineChartBarData(
                  spots: filteredData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value.heartRate.toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.red.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpO2Chart(List<PatientData> data) {
    final filteredData = _filterDataByPeriod(data);

    if (filteredData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Pas de données pour cette période')),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              // Correction: Forcer le graphique à ne pas dessiner en dehors de ses limites
              clipData: FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 5,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 &&
                          value.toInt() < filteredData.length) {
                        final time = filteredData[value.toInt()].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('HH:mm').format(time),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    interval: (filteredData.length / 5).ceilToDouble(),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              // Correction: Définir des limites raisonnables pour le SpO2
              minY: 80,
              maxY: 101,
              lineBarsData: [
                LineChartBarData(
                  spots: filteredData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      entry.value.spo2,
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataList(List<PatientData> data) {
    final filteredData = _filterDataByPeriod(data).take(20).toList();

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredData.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = filteredData[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: item.isNormal
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              child: Icon(
                item.isNormal ? Icons.check : Icons.warning,
                color: item.isNormal ? Colors.green : Colors.orange,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.heartRate} BPM',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${item.spo2.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Text(
              DateFormat('dd/MM/yyyy HH:mm:ss').format(item.timestamp),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.isNormal
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: item.isNormal ? Colors.green : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<PatientData> _filterDataByPeriod(List<PatientData> data) {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 0: // 24h
        startDate = now.subtract(const Duration(hours: 24));
        break;
      case 1: // 7 jours
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 2: // 30 jours
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = now.subtract(const Duration(hours: 24));
    }

    return data.where((d) => d.timestamp.isAfter(startDate)).toList();
  }
}
