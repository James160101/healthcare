import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:numberpicker/numberpicker.dart';
import '../models/patient.dart';
import '../services/firebase_service.dart';

class AddPatientScreen extends StatefulWidget {
  final Patient? patient;

  const AddPatientScreen({super.key, this.patient});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _familyContactController;

  late DateTime _birthDate;
  late int _currentHeight;
  late int _currentWeight;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient?.name ?? '');
    _phoneController = TextEditingController(text: widget.patient?.phone ?? '');
    _familyContactController = TextEditingController(text: widget.patient?.familyContact ?? '');
    _birthDate = widget.patient?.birthDate ?? DateTime(2000, 1, 1);
    _currentHeight = widget.patient?.height ?? 170;
    _currentWeight = widget.patient?.weight ?? 70;
  }

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
      final service = Provider.of<FirebaseService>(context, listen: false);
      final patientData = Patient(
        id: widget.patient?.id ?? '',
        name: _nameController.text,
        birthDate: _birthDate,
        height: _currentHeight,
        weight: _currentWeight,
        phone: _phoneController.text,
        familyContact: _familyContactController.text,
        imageUrl: widget.patient?.imageUrl ?? '',
      );
      if (widget.patient == null) {
        await service.addPatient(patientData);
      } else {
        await service.updatePatient(patientData);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: _birthDate,
          maximumDate: DateTime.now(),
          onDateTimeChanged: (DateTime newDate) {
            setState(() {
              _birthDate = newDate;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.patient != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Modifier le patient' : 'Ajouter un patient')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextRow('Nom', _nameController, validator: (v) => v!.isEmpty ? 'Nom requis' : null),
              _buildDateRow(context, 'Naissance', _birthDate),
              _buildPickerRow('Taille', 'cm', _currentHeight, 50, 250, (v) => setState(() => _currentHeight = v)),
              _buildPickerRow('Poids', 'kg', _currentWeight, 10, 200, (v) => setState(() => _currentWeight = v)),
              _buildTextRow('Téléphone', _phoneController, keyboard: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Numéro requis' : null),
              _buildTextRow('Famille', _familyContactController, keyboard: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Contact requis' : null),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEditing ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextRow(String label, TextEditingController controller, {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.end,
              decoration: const InputDecoration(border: InputBorder.none),
              keyboardType: keyboard,
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          TextButton(
            onPressed: () => _showDatePicker(context),
            child: Text(DateFormat('d MMMM yyyy', 'fr_FR').format(date)),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow(String label, String unit, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          NumberPicker(
            value: value,
            minValue: min,
            maxValue: max,
            step: 1,
            itemHeight: 40, // Plus compact
            itemWidth: 60,  // Plus compact
            onChanged: onChanged,
            axis: Axis.horizontal,
            haptics: true,
          ),
          Text(unit, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}
