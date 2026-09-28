import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medicine_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medicine_provider.dart';
import '../../theme/app_theme.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final MedicineModel? existingMedicine;
  final int? preSelectedCompartment;

  const AddEditMedicineScreen({
    super.key,
    this.existingMedicine,
    this.preSelectedCompartment,
  });

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _instructionsController;

  int _selectedCompartment = 1;
  List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
  List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool _isSaving = false;

  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final med = widget.existingMedicine;
    if (med != null) {
      _nameController = TextEditingController(text: med.name);
      _dosageController = TextEditingController(text: med.dosage);
      _instructionsController = TextEditingController(text: med.instructions);
      _selectedCompartment = med.compartment;
      _selectedDays = List.from(med.days);
      _selectedTimes = med.times.map((t) {
        final parts = t.split(':');
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }).toList();
    } else {
      _nameController = TextEditingController();
      _dosageController = TextEditingController();
      _instructionsController = TextEditingController();
      _selectedCompartment = widget.preSelectedCompartment ?? 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (!_selectedTimes.any((t) => t.hour == picked.hour && t.minute == picked.minute)) {
          _selectedTimes.add(picked);
          _selectedTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        }
      });
    }
  }

  void _removeTime(int index) {
    if (_selectedTimes.length > 1) {
      setState(() {
        _selectedTimes.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one dose time is required.')),
      );
    }
  }

  void _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dose time.')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final medicineProv = Provider.of<MedicineProvider>(context, listen: false);

    final uid = auth.userModel?.uid ?? auth.authUser?.uid;
    if (uid == null) return;

    // Occupied compartment validation
    final isOccupied = medicineProv.isCompartmentOccupied(
      _selectedCompartment,
      excludeMedicineId: widget.existingMedicine?.id,
    );

    if (isOccupied) {
      final confirmReassign = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Compartment Occupied'),
          content: Text(
            'Compartment $_selectedCompartment already has an active medicine. Reassigning will replace the slot assignment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
              child: const Text('Reassign Slot'),
            ),
          ],
        ),
      );

      if (confirmReassign != true) return;
    }

    setState(() {
      _isSaving = true;
    });

    final timesFormatted = _selectedTimes.map((t) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }).toList();

    final isEdit = widget.existingMedicine != null;
    final medicine = MedicineModel(
      id: widget.existingMedicine?.id ?? '',
      name: _nameController.text.trim(),
      compartment: _selectedCompartment,
      dosage: _dosageController.text.trim(),
      instructions: _instructionsController.text.trim(),
      times: timesFormatted,
      days: _selectedDays,
      active: true,
      createdAt: widget.existingMedicine?.createdAt ?? DateTime.now(),
    );

    final deviceId = auth.userModel?.deviceId ?? '';

    bool success;
    if (isEdit) {
      success = await medicineProv.updateMedicine(uid, medicine, deviceId: deviceId);
    } else {
      success = await medicineProv.addMedicine(uid, medicine, deviceId: deviceId);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Medicine updated successfully!' : 'Medicine added to Compartment $_selectedCompartment!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save medicine. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingMedicine != null;
    final medicineProv = Provider.of<MedicineProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medicine' : 'Add New Medicine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine Name
              Text(
                'Medicine Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name *',
                  hintText: 'e.g. Aspirin 100mg',
                  prefixIcon: Icon(Icons.medication_rounded),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Medicine name is required' : null,
              ),
              const SizedBox(height: 16),

              // Dosage & Instructions
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'e.g. 1 Pill',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        hintText: 'After meal',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Compartment Selector (1 to 6)
              Text(
                'Hardware Compartment Slot (1–6)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Select physical slot on your ESP32 organizer:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final compId = index + 1;
                  final isSelected = _selectedCompartment == compId;
                  final isOccupied = medicineProv.isCompartmentOccupied(
                    compId,
                    excludeMedicineId: widget.existingMedicine?.id,
                  );

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCompartment = compId;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryCyan
                            : (isOccupied ? AppTheme.cardBg : AppTheme.darkBackground),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryCyan
                              : (isOccupied ? AppTheme.warningAmber : AppTheme.cardBorder),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$compId',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          if (isOccupied && !isSelected)
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppTheme.warningAmber,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Daily Times Picker
              Text(
                'Schedule Configurator',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dose Times Daily', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.add_alarm_rounded, size: 18),
                    label: const Text('Add Time'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: List.generate(_selectedTimes.length, (i) {
                  final t = _selectedTimes[i];
                  final formatted =
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  return Chip(
                    label: Text(formatted, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: AppTheme.cardBg,
                    side: const BorderSide(color: AppTheme.primaryCyan),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => _removeTime(i),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Days Selector
              const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _allDays.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryCyan,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Phase 2 Load Cell Reserved UI Space (per ARD requirements)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.scale_rounded, color: AppTheme.neutralGray, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Load Cell (HX711) Tare & Weight Calibration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neutralGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Phase 1: Weight sensing disabled in hardware. Dose verification is strictly managed via Reed Switch (Lid Open/Close) triggers.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: null, // Disabled in Phase 1
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Calibrate Weight (Disabled - Phase 1)'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMedicine,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(isEdit ? 'Update Medicine' : 'Save & Assign to Hardware'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
