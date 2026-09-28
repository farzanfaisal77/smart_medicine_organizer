import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/medicine_model.dart';
import '../../../models/log_model.dart';
import '../../../providers/medicine_provider.dart';
import '../../../providers/device_provider.dart';
import '../../../providers/log_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../medicine/add_edit_medicine_screen.dart';
import '../../medicine/discontinue_medicine_dialog.dart';

class CompartmentGrid extends StatelessWidget {
  const CompartmentGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final medicineProvider = Provider.of<MedicineProvider>(context);
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row (Wrapped safely to prevent resolution overflow)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Compartments (2 Rows × 3 Cols)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'CPS Hardware',
                style: TextStyle(
                  color: AppTheme.primaryTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2 Rows x 3 Columns Grid (S1 to S6)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 columns -> 2 rows for 6 compartments
            childAspectRatio: 0.70, // Ample height ratio to avoid any vertical overflow
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            final compartmentId = index + 1;
            final slotTag = 'S$compartmentId';
            final medicine = medicineProvider.getMedicineForCompartment(compartmentId);
            final status = deviceProvider.getCompartmentStatus(compartmentId);

            final bool isOpen = status?.isOpen ?? false;
            final String ledColor = status?.ledColor ?? 'OFF'; // 'OFF', 'GREEN', 'RED', 'BLUE', etc.
            final bool isOccupied = medicine != null;

            // Compute styling and LED feedback
            Color cardBorderColor = AppTheme.cardBorder;
            Color ledBadgeBg = AppTheme.cardBorder;
            Color ledTextColor = AppTheme.neutralGray;
            String ledLabel = 'LED: Off';
            IconData ledIcon = Icons.lightbulb_outline_rounded;

            if (ledColor != 'OFF') {
              switch (ledColor) {
                case 'GREEN':
                  cardBorderColor = AppTheme.successGreen;
                  ledBadgeBg = AppTheme.successGreen.withOpacity(0.25);
                  ledTextColor = AppTheme.successGreen;
                  ledLabel = 'LED: Green';
                  break;
                case 'RED':
                  cardBorderColor = AppTheme.errorRed;
                  ledBadgeBg = AppTheme.errorRed.withOpacity(0.25);
                  ledTextColor = AppTheme.errorRed;
                  ledLabel = 'LED: Red';
                  break;
                case 'BLUE':
                  cardBorderColor = Colors.blueAccent;
                  ledBadgeBg = Colors.blueAccent.withOpacity(0.25);
                  ledTextColor = Colors.blueAccent;
                  ledLabel = 'LED: Blue';
                  break;
                case 'PURPLE':
                  cardBorderColor = Colors.purpleAccent;
                  ledBadgeBg = Colors.purpleAccent.withOpacity(0.25);
                  ledTextColor = Colors.purpleAccent;
                  ledLabel = 'LED: Purple';
                  break;
                case 'PINK':
                  cardBorderColor = Colors.pinkAccent;
                  ledBadgeBg = Colors.pinkAccent.withOpacity(0.25);
                  ledTextColor = Colors.pinkAccent;
                  ledLabel = 'LED: Pink';
                  break;
                case 'YELLOW':
                  cardBorderColor = Colors.yellowAccent;
                  ledBadgeBg = Colors.yellowAccent.withOpacity(0.25);
                  ledTextColor = Colors.yellowAccent;
                  ledLabel = 'LED: Yellow';
                  break;
                case 'CYAN':
                  cardBorderColor = AppTheme.primaryCyan;
                  ledBadgeBg = AppTheme.primaryCyan.withOpacity(0.25);
                  ledTextColor = AppTheme.primaryCyan;
                  ledLabel = 'LED: Cyan';
                  break;
                default:
                  cardBorderColor = Colors.white;
                  ledBadgeBg = Colors.white24;
                  ledTextColor = Colors.white;
                  ledLabel = 'LED: $ledColor';
                  break;
              }
              ledIcon = Icons.lightbulb_rounded;
            } else if (isOpen) {
              cardBorderColor = AppTheme.warningAmber;
            } else if (isOccupied) {
              cardBorderColor = AppTheme.primaryCyan.withOpacity(0.5);
            }

            return InkWell(
              onTap: () {
                if (isOccupied) {
                  _showCompartmentOptions(
                    context,
                    medicine!,
                    compartmentId,
                    isOpen,
                    ledColor,
                    authProvider.userModel?.uid ?? '',
                    authProvider.userModel?.deviceId ?? 'ESP32_001',
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddEditMedicineScreen(
                        preSelectedCompartment: compartmentId,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ledColor != 'OFF'
                      ? cardBorderColor.withOpacity(0.12)
                      : (isOpen ? AppTheme.warningAmber.withOpacity(0.08) : AppTheme.cardBg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorderColor, width: ledColor != 'OFF' ? 2 : 1.2),
                  boxShadow: ledColor != 'OFF'
                      ? [
                          BoxShadow(
                            color: cardBorderColor.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header row: Slot Tag S1..S6 & Reed Switch Lid Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slotTag,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          isOpen ? Icons.meeting_room_outlined : Icons.meeting_room_rounded,
                          size: 14,
                          color: isOpen ? AppTheme.warningAmber : AppTheme.successGreen,
                        ),
                      ],
                    ),

                    // Main Content: "Empty" OR Next Dosage Time
                    if (!isOccupied)
                      Center(
                        child: Text(
                          'Empty',
                          style: TextStyle(
                            color: AppTheme.neutralGray,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Next: ${medicineProvider.getNextDoseTimeForMedicine(medicine)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryCyan,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],

                    // Footer 1: Reed Switch State (Closed / Open)
                    Text(
                      isOpen ? 'Lid Open' : 'Lid Closed',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppTheme.warningAmber : AppTheme.successGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Footer 2: LED Color Feedback Pill
                    GestureDetector(
                      onTap: () {
                        // Quick toggle LED color directly on tap!
                        final uid = authProvider.userModel?.uid ?? '';
                        final deviceId = authProvider.userModel?.deviceId ?? 'ESP32_001';
                        final nextColors = ['OFF', 'GREEN', 'RED', 'BLUE', 'PURPLE', 'PINK', 'YELLOW'];
                        final nextIndex = (nextColors.indexOf(ledColor) + 1) % nextColors.length;
                        deviceProvider.updateCompartmentLedColor(
                          uid: uid,
                          deviceId: deviceId,
                          compartmentId: compartmentId,
                          color: nextColors[nextIndex],
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: ledBadgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(ledIcon, size: 9, color: ledTextColor),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                ledLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ledTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        // Simulated Hardware Test Controls (Optional Dev Tools)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.developer_board_rounded, size: 16, color: AppTheme.primaryCyan),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hardware Test Simulator (Dev Mode)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Simulate ESP32 Reed Switch & LED color triggers before hardware pairing:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 8),

                // Reed Switch Lid Toggles
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(6, (i) {
                      final compId = i + 1;
                      final status = deviceProvider.getCompartmentStatus(compId);
                      final isOpen = status?.isOpen ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: FilterChip(
                          visualDensity: VisualDensity.compact,
                          selected: isOpen,
                          label: Text('S$compId ${isOpen ? "OPEN" : "CLOSED"}'),
                          labelStyle: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? Colors.black : Colors.white,
                          ),
                          selectedColor: AppTheme.warningAmber,
                          backgroundColor: AppTheme.cardBorder,
                          onSelected: (selected) {
                            final uid = authProvider.userModel?.uid ?? '';
                            final deviceId = authProvider.userModel?.deviceId ?? 'ESP32_001';
                            deviceProvider.simulateLidTrigger(
                              uid: uid,
                              deviceId: deviceId,
                              compartmentId: compId,
                              isOpen: selected,
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 6),

                // LED Color Toggle Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(6, (i) {
                      final compId = i + 1;
                      final status = deviceProvider.getCompartmentStatus(compId);
                      final currentColor = status?.ledColor ?? 'OFF';

                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'S$compId:',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: () {
                                final uid = authProvider.userModel?.uid ?? '';
                                final deviceId = authProvider.userModel?.deviceId ?? 'ESP32_001';
                                String nextColor = 'OFF';
                                if (currentColor == 'OFF') nextColor = 'GREEN';
                                else if (currentColor == 'GREEN') nextColor = 'RED';
                                deviceProvider.simulateLedColor(
                                  uid: uid,
                                  deviceId: deviceId,
                                  compartmentId: compId,
                                  ledColor: nextColor,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: currentColor == 'GREEN'
                                      ? AppTheme.successGreen
                                      : (currentColor == 'RED'
                                          ? AppTheme.errorRed
                                          : AppTheme.neutralGray),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  currentColor,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCompartmentOptions(
    BuildContext context,
    MedicineModel medicine,
    int compartmentId,
    bool isOpen,
    String ledColor,
    String uid,
    String deviceId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final deviceProv = Provider.of<DeviceProvider>(context);
        final currentLedColor = deviceProv.getCompartmentStatus(compartmentId)?.ledColor ?? ledColor;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Slot S$compartmentId • ${medicine.dosage}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isOpen ? AppTheme.warningAmber : AppTheme.successGreen)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOpen ? 'Lid Open' : 'Lid Closed',
                          style: TextStyle(
                            color: isOpen ? AppTheme.warningAmber : AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Real-Time LED Color Picker Row
                  Text(
                    'Hardware LED Indicator Color (Real-Time):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neutralGray),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'GREEN',
                        'OFF',
                        'RED',
                        'BLUE',
                        'PURPLE',
                        'PINK',
                        'YELLOW',
                        'CYAN',
                      ].map((color) {
                        final bool isSelected = currentLedColor == color;
                        Color colorBorder = AppTheme.cardBorder;
                        if (color == 'GREEN') colorBorder = AppTheme.successGreen;
                        if (color == 'RED') colorBorder = AppTheme.errorRed;
                        if (color == 'BLUE') colorBorder = Colors.blueAccent;
                        if (color == 'PURPLE') colorBorder = Colors.purpleAccent;
                        if (color == 'PINK') colorBorder = Colors.pinkAccent;
                        if (color == 'YELLOW') colorBorder = Colors.yellowAccent;
                        if (color == 'CYAN') colorBorder = AppTheme.primaryCyan;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(color),
                            selected: isSelected,
                            selectedColor: colorBorder.withOpacity(0.3),
                            backgroundColor: AppTheme.cardBorder,
                            labelStyle: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? colorBorder : Colors.white70,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                deviceProv.updateCompartmentLedColor(
                                  uid: uid,
                                  deviceId: deviceId,
                                  compartmentId: compartmentId,
                                  color: color,
                                );
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.cardBorder),
                  const SizedBox(height: 4),

                  ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
                    title: const Text('Mark Dose as TAKEN Today', style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Log dose as taken and advance hardware to next medicine'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final log = LogModel(
                        id: '',
                        compartment: compartmentId,
                        timestamp: DateTime.now(),
                        eventType: EventType.taken,
                        details: 'C$compartmentId Manual dose taken for ${medicine.name}',
                      );
                      final logProv = Provider.of<LogProvider>(context, listen: false);
                      await logProv.addLog(uid, log);
                      final medProv = Provider.of<MedicineProvider>(context, listen: false);
                      await medProv.syncNextDoseToDevice(deviceId, logs: logProv.logs);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dose for ${medicine.name} marked TAKEN! Next dose synced to hardware.'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: AppTheme.primaryCyan),
                    title: const Text('Edit Medicine Details'),
                    subtitle: const Text('Change schedule, times or instructions'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddEditMedicineScreen(existingMedicine: medicine),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.do_not_disturb_on_rounded, color: AppTheme.errorRed),
                    title: const Text(
                      'Discontinue / Delete Medicine',
                      style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Clear physical compartment & remove from hardware memory'),
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (_) => DiscontinueMedicineDialog(
                          medicine: medicine,
                          uid: uid,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
