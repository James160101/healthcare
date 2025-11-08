import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/image_slideshow.dart'; // Réimportation du widget
import 'add_patient_screen.dart';
import 'real_time_monitor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final Doctor? doctor = service.currentDoctor;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bonjour, \nDr, ${doctor?.name ?? 'Utilisateur'}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('👋', style: TextStyle(fontSize: 28)),
              ],
            ),
            const SizedBox(height: 24),
            const ImageSlideshow(), // Ajout du diaporama d'images
            const SizedBox(height: 24),
            const Text(
              'Patients',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPatientList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddPatientScreen()),
        ),
        tooltip: 'Ajouter un patient',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPatientList() {
    return Consumer<FirebaseService>(
      builder: (context, service, child) {
        if (service.patients.isEmpty) {
          return const Center(child: Text('Aucun patient trouvé.'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: service.patients.length,
          itemBuilder: (context, index) {
            final patient = service.patients[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildPatientCard(patient),
            );
          },
        );
      },
    );
  }

  Widget _buildPatientCard(Patient patient) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nom: ${patient.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Âge: ${patient.age}', style: const TextStyle(color: Colors.white)),
                  Text('Taille: ${patient.height}cm', style: const TextStyle(color: Colors.white)),
                  Text('Poids: ${patient.weight}kg', style: const TextStyle(color: Colors.white)),
                  Text('Téléphone: ${patient.phone}', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () {
                Provider.of<FirebaseService>(context, listen: false).selectPatient(patient.id);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const RealTimeMonitor(),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
