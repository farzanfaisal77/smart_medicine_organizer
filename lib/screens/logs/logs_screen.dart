import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/log_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/log_provider.dart';
import '../../theme/app_theme.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logProvider = Provider.of<LogProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final logs = logProvider.filteredLogs;

    return Column(
      children: [
        // App Bar & Title
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Real-Time Activity Logs',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryCyan),
                    tooltip: 'Simulate Log Event',
                    onPressed: () => _showSimulateLogDialog(context, auth.userModel?.uid ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Live Reed Switch lid trigger adherence feed from ESP32',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),

              // Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Filter by Event Type
                    DropdownButton<EventType?>(
                      dropdownColor: AppTheme.cardBg,
                      value: logProvider.eventTypeFilter,
                      hint: const Text('All Event Types', style: TextStyle(fontSize: 13)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Events')),
                        DropdownMenuItem(value: EventType.taken, child: Text('✅ TAKEN')),
                        DropdownMenuItem(value: EventType.missed, child: Text('❌ MISSED')),
                        DropdownMenuItem(
                          value: EventType.wrongCompartment,
                          child: Text('⚠️ WRONG COMPARTMENT'),
                        ),
                      ],
                      onChanged: (val) => logProvider.setEventTypeFilter(val),
                    ),
                    const SizedBox(width: 12),

                    // Filter by Compartment
                    DropdownButton<int?>(
                      dropdownColor: AppTheme.cardBg,
                      value: logProvider.compartmentFilter,
                      hint: const Text('All Compartments', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Slots')),
                        ...List.generate(
                          6,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Slot ${i + 1}'),
                          ),
                        ),
                      ],
                      onChanged: (val) => logProvider.setCompartmentFilter(val),
                    ),
                    const SizedBox(width: 12),

                    if (logProvider.compartmentFilter != null ||
                        logProvider.eventTypeFilter != null)
                      TextButton.icon(
                        onPressed: () => logProvider.clearFilters(),
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Reset'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(color: AppTheme.cardBorder, height: 1),

        // Log Entries Feed
        Expanded(
          child: logProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : logs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 48,
                              color: AppTheme.neutralGray,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No activity logs found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reed Switch lid triggers from your ESP32 device will appear here in real-time.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showSimulateLogDialog(context, auth.userModel?.uid ?? ''),
                              icon: const Icon(Icons.flash_on_rounded, size: 18),
                              label: const Text('Simulate Reed Switch Trigger'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final timeStr = DateFormat('hh:mm a • MMM dd').format(log.timestamp);

                        Color statusColor;
                        IconData iconData;
                        String badgeText;

                        switch (log.eventType) {
                          case EventType.taken:
                            statusColor = AppTheme.successGreen;
                            iconData = Icons.check_circle_rounded;
                            badgeText = 'TAKEN';
                            break;
                          case EventType.missed:
                            statusColor = AppTheme.errorRed;
                            iconData = Icons.cancel_rounded;
                            badgeText = 'MISSED';
                            break;
                          case EventType.wrongCompartment:
                          default:
                            statusColor = AppTheme.warningAmber;
                            iconData = Icons.warning_amber_rounded;
                            badgeText = 'WRONG SLOT';
                            break;
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor.withOpacity(0.15),
                                ),
                                child: Icon(iconData, color: statusColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Compartment ${log.compartment}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      log.details.isNotEmpty
                                          ? log.details
                                          : 'Reed switch triggered',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.neutralGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showSimulateLogDialog(BuildContext context, String uid) {
    int selectedSlot = 1;
    EventType selectedType = EventType.taken;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: const Text('Simulate Reed Switch Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Simulate a hardware Reed Switch trigger sending adherence logs to Firestore.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedSlot,
                    dropdownColor: AppTheme.cardBg,
                    decoration: const InputDecoration(labelText: 'Compartment Slot'),
                    items: List.generate(
                      6,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('Slot ${i + 1}')),
                    ),
                    onChanged: (v) => setModalState(() => selectedSlot = v ?? 1),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EventType>(
                    value: selectedType,
                    dropdownColor: AppTheme.cardBg,
                    decoration: const InputDecoration(labelText: 'Event Type'),
                    items: const [
                      DropdownMenuItem(value: EventType.taken, child: Text('TAKEN (Lid Opened on Time)')),
                      DropdownMenuItem(value: EventType.missed, child: Text('MISSED (No Lid Activity)')),
                      DropdownMenuItem(
                        value: EventType.wrongCompartment,
                        child: Text('WRONG_COMPARTMENT (Wrong Lid Opened)'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => selectedType = v ?? EventType.taken),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String details = 'Reed switch trigger';
                    if (selectedType == EventType.taken) {
                      details = 'Compartment $selectedSlot opened on schedule.';
                    } else if (selectedType == EventType.missed) {
                      details = 'No lid activity detected for Compartment $selectedSlot within 60 mins.';
                    } else {
                      details = 'Unscheduled compartment $selectedSlot opened!';
                    }

                    final newLog = LogModel(
                      id: '',
                      compartment: selectedSlot,
                      timestamp: DateTime.now(),
                      eventType: selectedType,
                      details: details,
                    );

                    await Provider.of<LogProvider>(context, listen: false).addLog(uid, newLog);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Log Hardware Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
