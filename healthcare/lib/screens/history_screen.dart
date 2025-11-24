import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/patient_data.dart';
import '../widgets/heartbeat_loader.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(patientName != null ? 'Historique: $patientName' : 'Historique médical'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return Center(child: HeartbeatLoader(size: 60, color: theme.colorScheme.primary, message: "Chargement..."));
          }
          if (service.historyData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.query_stats, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Aucune donnée disponible pour cette période', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 16),
              _buildModernFilterBar(service, theme),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHistoryChartCard(
                        theme,
                        title: 'Fréquence Cardiaque',
                        history: service.historyData,
                        dataExtractor: (data) => _clampValue(data.heartRate.toDouble(), 40, 180),
                        color: Colors.redAccent,
                        minY: 40,
                        maxY: 180,
                        unit: ' BPM',
                        icon: Icons.favorite,
                      ),
                      const SizedBox(height: 24),
                      _buildHistoryChartCard(
                        theme,
                        title: 'Saturation Oxygène (SpO2)',
                        history: service.historyData,
                        dataExtractor: (data) => _clampValue(data.spo2, 80, 100),
                        color: Colors.blueAccent,
                        minY: 80,
                        maxY: 100,
                        unit: '%',
                        icon: Icons.water_drop,
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildModernFilterBar(FirebaseService service, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterButton('24h', HistoryRange.day, service, theme),
          const SizedBox(width: 12),
          _buildFilterButton('Semaine', HistoryRange.week, service, theme),
          const SizedBox(width: 12),
          _buildFilterButton('Mois', HistoryRange.month, service, theme),
          const SizedBox(width: 12),
          _buildFilterButton('Tout', HistoryRange.all, service, theme),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, HistoryRange range, FirebaseService service, ThemeData theme) {
    final isSelected = _selectedRange == range;
    return InkWell(
      onTap: () {
        setState(() => _selectedRange = range);
        service.filterHistoryByRange(range);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected 
              ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryChartCard(
      ThemeData theme, {
      required String title,
      required List<PatientData> history,
      required double Function(PatientData) dataExtractor,
      required Color color,
      required double minY,
      required double maxY,
      required String unit,
      required IconData icon,
  }) {
    final chartData = history.reversed.toList();
    
    // Calculer moyenne pour afficher
    double avg = 0;
    if (chartData.isNotEmpty) {
       avg = chartData.map((e) => dataExtractor(e)).reduce((a, b) => a + b) / chartData.length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                "Moy: ${avg.toStringAsFixed(1)}$unit",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY, maxY: maxY,
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1, dashArray: [5, 5]),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Cleaner sans axe Y visible
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      reservedSize: 30, 
                      interval: (chartData.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                          final time = chartData[value.toInt()].timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('HH:mm').format(time), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade900, // Correction ICI
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '${touchedSpot.y.toStringAsFixed(1)}$unit',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (int i = 0; i < chartData.length; i++) FlSpot(i.toDouble(), dataExtractor(chartData[i]))],
                    isCurved: true, 
                    color: color, 
                    barWidth: 3, 
                    isStrokeCapRound: true, 
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true, 
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.0)], 
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
