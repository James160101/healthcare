import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirebaseService>(context, listen: false);
    final user = service.currentDoctor;

    final imageUrl = user?.imageUrl;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(user?.name ?? 'Utilisateur'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                  ? NetworkImage(imageUrl)
                  : null,
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historique'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text("Liste de l'alerte"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/alerts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notification'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () async {
              Navigator.pop(context);
              await service.signOut();
              // Naviguer vers le login et supprimer toutes les routes précédentes
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
            },
          ),
        ],
      ),
    );
  }
}
