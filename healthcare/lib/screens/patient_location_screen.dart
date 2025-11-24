import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';

class PatientLocationScreen extends StatefulWidget {
  final String patientName;
  final String patientId;

  const PatientLocationScreen({super.key, required this.patientName, required this.patientId});

  @override
  State<PatientLocationScreen> createState() => _PatientLocationScreenState();
}

class _PatientLocationScreenState extends State<PatientLocationScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationService>(context, listen: false).listenToPatientLocation(widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Localisation: ${widget.patientName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Consumer<LocationService>(
        builder: (context, locationService, child) {
          if (locationService.currentPosition == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(locationService.statusMessage),
                ],
              ),
            );
          }

          final currentLatLng = LatLng(
            locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude,
          );
          
          // Logique pour déterminer si le patient est "Actif"
          final timestamp = locationService.currentPosition!.timestamp;
          // Si le signal date de moins de 2 minutes, on considère que c'est actif (vert)
          final isOnline = DateTime.now().difference(timestamp).inMinutes < 2;
          
          final Color statusColor = isOnline ? Colors.green : Colors.red;
          final String statusText = isOnline ? "En ligne" : "Hors ligne";

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLatLng,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.healthcare.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLatLng,
                        width: 100, // Un peu plus large pour le texte
                        height: 100,
                        child: Column(
                          children: [
                            // Indicateur visuel (Point Vert/Rouge sur l'icône)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: statusColor, // Couleur dynamique
                                  size: 50,
                                ),
                                if (isOnline) // Petit point blanc au milieu pour style
                                  const Positioned(
                                    top: 12,
                                    child: Icon(Icons.bolt, color: Colors.white, size: 20),
                                  )
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor, width: 2),
                              ),
                              child: Text(
                                "$statusText\n${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  backgroundColor: statusColor,
                  onPressed: () {
                     _mapController.move(currentLatLng, 15.0);
                  },
                  child: const Icon(Icons.center_focus_strong),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
