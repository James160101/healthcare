import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numberpicker/numberpicker.dart';
import '../models/patient.dart';
import '../services/firebase_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _familyContactController = TextEditingController();

  int _currentAge = 30;
  int _currentHeight = 170;
  int _currentWeight = 70;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _familyContactController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPatient = Patient(
        id: '', // ID sera généré par Firebase
        name: _nameController.text,
        age: _currentAge,
        height: _currentHeight,
        weight: _currentWeight,
        phone: _phoneController.text,
        familyContact: _familyContactController.text,
        imageUrl: '',
      );

      await Provider.of<FirebaseService>(context, listen: false).addPatient(newPatient);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un patient')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 24),
              _buildNumberPicker(
                label: 'Âge',
                value: _currentAge,
                minValue: 0,
                maxValue: 120,
                onChanged: (value) => setState(() => _currentAge = value),
              ),
              const SizedBox(height: 24),
              _buildNumberPicker(
                label: 'Taille (cm)',
                value: _currentHeight,
                minValue: 50,
                maxValue: 250,
                onChanged: (value) => setState(() => _currentHeight = value),
              ),
              const SizedBox(height: 24),
              _buildNumberPicker(
                label: 'Poids (kg)',
                value: _currentWeight,
                minValue: 10,
                maxValue: 200,
                onChanged: (value) => setState(() => _currentWeight = value),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un numéro' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _familyContactController,
                decoration: const InputDecoration(labelText: 'Contact de la famille'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Veuillez entrer un contact' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enregistrer le patient'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        NumberPicker(
          value: value,
          minValue: minValue,
          maxValue: maxValue,
          onChanged: onChanged,
          haptics: true,
          textStyle: const TextStyle(fontSize: 16, color: Colors.grey),
          selectedTextStyle: const TextStyle(fontSize: 28, color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
