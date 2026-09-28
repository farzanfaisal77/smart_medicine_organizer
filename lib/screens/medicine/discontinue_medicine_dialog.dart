import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medicine_model.dart';
import '../../providers/medicine_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class DiscontinueMedicineDialog extends StatefulWidget {
  final MedicineModel medicine;
  final String uid;

  const DiscontinueMedicineDialog({
    super.key,
    required this.medicine,
    required this.uid,
  });

  @override
  State<DiscontinueMedicineDialog> createState() => _DiscontinueMedicineDialogState();
}

class _DiscontinueMedicineDialogState extends State<DiscontinueMedicineDialog> {
  bool _isProcessing = false;

  void _confirmDiscontinue() async {
    setState(() {
      _isProcessing = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final deviceId = auth.userModel?.deviceId ?? '';
    final medProv = Provider.of<MedicineProvider>(context, listen: false);
    final success = await medProv.discontinueMedicine(widget.uid, widget.medicine.id, deviceId: deviceId);

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Medicine discontinued. Compartment ${widget.medicine.compartment} cleared.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to discontinue medicine.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Discontinue Medicine',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cleaning_services_rounded, color: AppTheme.warningAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please clear physical Compartment ${widget.medicine.compartment} before confirming.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'This action will update ESP32 memory, cancel all active hardware RTC alarms, and turn off any active LEDs for Compartment ${widget.medicine.compartment}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _confirmDiscontinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorRed,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm & Discontinue'),
        ),
      ],
    );
  }
}
