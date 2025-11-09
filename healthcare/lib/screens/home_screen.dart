import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/patient.dart';
import '../widgets/image_slideshow.dart';
import 'add_patient_screen.dart';
import 'real_time_monitor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const ImageSlideshow(),
            const SizedBox(height: 24),
            const Text(
              'Patients',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher un patient...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      onChanged: (value) {
        Provider.of<FirebaseService>(context, listen: false).searchPatients(value);
      },
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
              child: _buildDismissiblePatientCard(context, patient),
            );
          },
        );
      },
    );
  }

  Widget _buildDismissiblePatientCard(BuildContext context, Patient patient) {
    return Dismissible(
      key: Key(patient.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Confirmer la suppression'),
              content: Text('Voulez-vous vraiment supprimer ${patient.name} ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Non'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Oui'),
                ),
              ],
            );
          },
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) {
        Provider.of<FirebaseService>(context, listen: false).deletePatient(patient.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${patient.name} a été supprimé')),
        );
      },
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 8),
            Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: _buildPatientCard(context, patient),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient) {
    final heightInMeters = (patient.height / 100).toStringAsFixed(2);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Provider.of<FirebaseService>(context, listen: false).selectPatient(patient.id);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const RealTimeMonitor(),
          ));
        },
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
                    Text('Âge: ${patient.age}', style: const TextStyle(color: Colors.white)), // Utilise le getter pour l'âge
                    Text('Taille: $heightInMeters m', style: const TextStyle(color: Colors.white)), // Affiche en mètres
                    Text('Poids: ${patient.weight}kg', style: const TextStyle(color: Colors.white)),
                    Text('Téléphone: ${patient.phone}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AddPatientScreen(patient: patient),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
