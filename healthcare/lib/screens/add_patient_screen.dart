import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  late TextEditingController _addressController;
  String? _selectedDeviceId;

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
    _addressController = TextEditingController(text: widget.patient?.address ?? '');
    _selectedDeviceId = widget.patient?.deviceId;
    _birthDate = widget.patient?.birthDate ?? DateTime(2000, 1, 1);
    _currentHeight = widget.patient?.height ?? 170;
    _currentWeight = widget.patient?.weight ?? 70;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _familyContactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner un appareil.")));
      return;
    }

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
        address: _addressController.text,
        imageUrl: widget.patient?.imageUrl ?? '',
        deviceId: _selectedDeviceId!,
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

  void _showModalPicker(BuildContext context, Widget child) {
    showCupertinoModalPopup(context: context, builder: (_) => Container(height: 250, color: Colors.white, child: child));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.patient != null;
    final deviceIds = Provider.of<FirebaseService>(context).deviceIds;
    final dropdownValue = _selectedDeviceId != null && deviceIds.contains(_selectedDeviceId) ? _selectedDeviceId : null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Modifier le patient' : 'Ajouter un patient')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextRow('Nom', _nameController, validator: (value) {
                if (value == null || value.isEmpty) return 'Nom requis';
                if (!RegExp(r'^[a-zA-Z\s-]+').hasMatch(value)) return 'Lettres, espaces et tirets uniquement';
                return null;
              }),
              _buildPickerRow(context, 'Naissance', DateFormat('d MMMM yyyy', 'fr_FR').format(_birthDate), () {
                _showModalPicker(context, CupertinoDatePicker(mode: CupertinoDatePickerMode.date, initialDateTime: _birthDate, maximumDate: DateTime.now(), onDateTimeChanged: (newDate) => setState(() => _birthDate = newDate)));
              }),
              _buildPickerRow(context, 'Taille', '$_currentHeight cm', () {
                 _showModalPicker(context, CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: _currentHeight - 50), itemExtent: 32.0, onSelectedItemChanged: (index) => setState(() => _currentHeight = index + 50), children: List<Widget>.generate(201, (index) => Center(child: Text('${index + 50}')))));
              }),
               _buildPickerRow(context, 'Poids', '$_currentWeight kg', () {
                 _showModalPicker(context, CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: _currentWeight - 10), itemExtent: 32.0, onSelectedItemChanged: (index) => setState(() => _currentWeight = index + 10), children: List<Widget>.generate(191, (index) => Center(child: Text('${index + 10}')))));
              }),
              _buildTextRow('Adresse', _addressController, validator: (v) => v!.isEmpty ? 'Adresse requise' : null),
              _buildTextRow('Téléphone', _phoneController, keyboard: TextInputType.phone, validator: (value) {
                if (value == null || value.isEmpty) return 'Numéro requis';
                if (!RegExp(r'^(\+261|0)(32|33|34|37|38)[0-9]{7}$').hasMatch(value.replaceAll(' ', ''))) return 'Format de numéro malgache invalide';
                return null;
              }),
              _buildTextRow('Famille', _familyContactController, keyboard: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Contact requis' : null),
              _buildDeviceDropdown(deviceIds, dropdownValue),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceDropdown(List<String> deviceIds, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Appareil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          DropdownButton<String>(
            value: value,
            hint: const Text('Sélectionner'),
            items: deviceIds.map((String id) => DropdownMenuItem<String>(value: id, child: Text(id))).toList(),
            onChanged: (String? newValue) => setState(() => _selectedDeviceId = newValue),
          ),
        ],
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
            child: TextFormField(controller: controller, textAlign: TextAlign.end, decoration: const InputDecoration(border: InputBorder.none), keyboardType: keyboard, validator: validator)),
        ],
      ),
    );
  }

  Widget _buildPickerRow(BuildContext context, String label, String value, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          TextButton(onPressed: onPressed, child: Text(value)),
        ],
      ),
    );
  }
}
