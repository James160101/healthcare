import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/doctor.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final Doctor? doctor = service.currentDoctor;
    final String initial = doctor?.name.isNotEmpty == true ? doctor!.name[0].toUpperCase() : '?';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.shade300, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(initial, style: const TextStyle(fontSize: 28, color: Colors.blue)),
                ),
                const SizedBox(height: 10),
                Text(
                  doctor?.name ?? 'Utilisateur',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  doctor?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          _buildDrawerItem(context, icon: Icons.person_outline, text: 'Profil', route: '/profile'),
          _buildDrawerItem(context, icon: Icons.notifications_none, text: 'Alertes', route: '/alerts', onTap: () {
            service.markAlertsAsRead();
            Navigator.pushNamed(context, '/alerts');
          }),
          _buildDrawerItem(context, icon: Icons.stacked_line_chart, text: 'Statistiques', route: '/statistics'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () {
              Navigator.of(context).pop(); // Ferme le drawer
              service.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String text, String? route, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () {
        Navigator.of(context).pop(); // Ferme le drawer
        if (onTap != null) {
          onTap();
        } else if (route != null && ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
