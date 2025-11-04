import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
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
    // Animation pour le pulse du coeur
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

  Color _getHeartRateColor(int heartRate) {
    if (heartRate > 100) return Colors.red;
    if (heartRate < 60) return Colors.orange;
    return Colors.green;
  }

  Color _getSpo2Color(double spo2) {
    if (spo2 < 90) return Colors.red;
    if (spo2 < 95) return Colors.orange;
    return Colors.green;
  }

  String _getTimeSinceUpdate(DateTime lastUpdate) {
    final duration = DateTime.now().difference(lastUpdate);
    if (duration.inSeconds < 60) {
      return 'il y a ${duration.inSeconds} sec';
    } else if (duration.inMinutes < 60) {
      return 'il y a ${duration.inMinutes} min';
    } else {
      return 'il y a ${duration.inHours} h';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Temps Réel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FirebaseService>().loadHistory();
            },
          ),
        ],
      ),
      body: Consumer<FirebaseService>(
        builder: (context, service, _) {
          if (service.isLoading && service.historyData.isEmpty) {
            return _buildWaitingState("Chargement de l'historique...");
          }

          if (service.error != null) {
            return _buildErrorState(service.error!);
          }

          if (service.historyData.isEmpty) {
            return _buildWaitingState("En attente de la première mesure...");
          }

          // La donnée la plus récente est le premier élément de l'historique.
          final latest = service.historyData.first;

          return RefreshIndicator(
            onRefresh: () => service.loadHistory(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header avec animation
                  _buildAnimatedHeader(latest),

                  // Cartes des signes vitaux
                  _buildVitalCards(latest),

                  // Graphiques en temps réel
                  _buildRealtimeGraph(service),

                  // Alertes
                  _buildAlerts(latest),

                  // Dernières mesures
                  _buildRecentMeasurements(service),
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
        gradient: LinearGradient(
          colors: [
            statusColor.withAlpha((255 * 0.2).round()),
            statusColor.withAlpha((255 * 0.05).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Animation du coeur
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Icon(
                  Icons.favorite,
                  size: 60,
                  color: statusColor,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Text(
            data.status,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _getTimeSinceUpdate(data.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),

          Text(
            DateFormat('HH:mm:ss - dd/MM/yyyy').format(data.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
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
              Expanded(
                child: VitalCard(
                  icon: Icons.favorite,
                  iconColor: Colors.red,
                  label: 'Fréquence Cardiaque',
                  value: data.heartRate.toString(),
                  unit: 'BPM',
                  status: data.heartRateStatus,
                  statusColor: _getHeartRateColor(data.heartRate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VitalCard(
                  icon: Icons.water_drop,
                  iconColor: Colors.blue,
                  label: 'Saturation O₂',
                  value: data.spo2.toStringAsFixed(1),
                  unit: '%',
                  status: data.spo2Status,
                  statusColor: _getSpo2Color(data.spo2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Indicateurs supplémentaires
          Row(
            children: [
              Expanded(
                child: _buildIndicatorCard(
                  'Plage Normale BPM',
                  '60-100',
                  Icons.trending_neutral,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIndicatorCard(
                  'Plage Normale SpO₂',
                  '95-100%',
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeGraph(FirebaseService service) {
    final recentData = service.historyData.take(20).toList().reversed.toList();

    if (recentData.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tendances (20 dernières mesures)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildMiniGraph(recentData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniGraph(List<PatientData> data) {
    return SizedBox(
      height: 80,
      child: Row(
        children: data.asMap().entries.map((entry) {
          final item = entry.value;
          final normalizedBPM = (item.heartRate - 40) / 100;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _getHeartRateColor(item.heartRate).withAlpha((255 * 0.7).round()),
                borderRadius: BorderRadius.circular(2),
              ),
              height: normalizedBPM * 80,
              alignment: Alignment.bottomCenter,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlerts(PatientData data) {
    final alerts = <Map<String, dynamic>>[];

    if (data.heartRate < 60) {
      alerts.add({
        'icon': Icons.arrow_downward,
        'color': Colors.orange,
        'title': 'Bradycardie',
        'message': 'Fréquence cardiaque faible (${data.heartRate} BPM)',
      });
    } else if (data.heartRate > 100) {
      alerts.add({
        'icon': Icons.arrow_upward,
        'color': Colors.red,
        'title': 'Tachycardie',
        'message': 'Fréquence cardiaque élevée (${data.heartRate} BPM)',
      });
    }

    if (data.spo2 < 95) {
      alerts.add({
        'icon': Icons.warning,
        'color': data.spo2 < 90 ? Colors.red : Colors.orange,
        'title': data.spo2 < 90 ? 'SpO₂ Critique' : 'SpO₂ Faible',
        'message': 'Saturation en oxygène: ${data.spo2.toStringAsFixed(1)}%',
      });
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: alerts.map((alert) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (alert['color'] as Color).withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (alert['color'] as Color).withAlpha((255 * 0.3).round()),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(alert['icon'], color: alert['color'], size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: alert['color'],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['message'],
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentMeasurements(FirebaseService service) {
    final recent = service.historyData.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Dernières Mesures',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...recent.map((data) => ListTile(
              leading: Icon(Icons.show_chart, color: _getStatusColor(data)),
              title: Text('FC: ${data.heartRate} BPM, SpO₂: ${data.spo2.toStringAsFixed(1)}%'),
              subtitle: Text(DateFormat('HH:mm:ss').format(data.timestamp)),
              trailing: Text(_getTimeSinceUpdate(data.timestamp)),
            )),
          ],
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
}
