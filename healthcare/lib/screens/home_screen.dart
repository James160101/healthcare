import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/patient.dart';
import '../models/patient_data.dart';
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
            _buildDashboard(),
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

  Widget _buildDashboard() {
    return Consumer<FirebaseService>(
      builder: (context, service, child) {
        int normalPatients = 0;
        int mediumAlerts = 0;
        int severeAlerts = 0;

        for (var patient in service.patients) {
          final data = patient.latestData;
          if (data != null) {
            if (data.isCritical) {
              severeAlerts++;
            } else if (!data.isNormal) {
              mediumAlerts++;
            } else {
              normalPatients++;
            }
          } else {
            normalPatients++;
          }
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8, // Adjust for a more rectangular look
          children: [
             _buildDashboardCard(
              context: context,
              title: 'Patients Totaux',
              value: service.patients.length.toString(),
              icon: Icons.people_outline,
              color: Colors.blue,
            ),
            _buildDashboardCard(
              context: context,
              title: 'État Normal',
              value: normalPatients.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _buildDashboardCard(
              context: context,
              title: 'Alerte Moyenne',
              value: mediumAlerts.toString(),
              icon: Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
            _buildDashboardCard(
              context: context,
              title: 'État Grave',
              value: severeAlerts.toString(),
              icon: Icons.dangerous_outlined,
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(icon, size: 28, color: Colors.white),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
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
                    Text('Âge: ${patient.age}', style: const TextStyle(color: Colors.white)),
                    Text('Taille: $heightInMeters m', style: const TextStyle(color: Colors.white)),
                    Text('Poids: ${patient.weight}kg', style: const TextStyle(color: Colors.white)),
                    Text('Adresse: ${patient.address}', style: const TextStyle(color: Colors.white)),
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
