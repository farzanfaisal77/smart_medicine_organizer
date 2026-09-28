import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/device_pairing_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _buzzerVolume;
  late double _buzzerDuration;
  late bool _pushEnabled;
  late bool _smsEnabled;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = Provider.of<AuthProvider>(context).userModel;
      _buzzerVolume = (user?.buzzerVolume ?? 80).toDouble();
      _buzzerDuration = (user?.buzzerDuration ?? 30).toDouble();
      _pushEnabled = user?.pushNotificationsEnabled ?? true;
      _smsEnabled = user?.smsNotificationsEnabled ?? false;
      _initialized = true;
    }
  }

  void _saveHardwareConfig() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.updateSettings(
      volume: _buzzerVolume.toInt(),
      duration: _buzzerDuration.toInt(),
      pushEnabled: _pushEnabled,
      smsEnabled: _smsEnabled,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings & ESP32 config updated in real-time!'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App & Device Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User & Device Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryCyan.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: AppTheme.primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Paired Device: ${user?.deviceId ?? "None"}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryCyan),
                    tooltip: 'Re-pair Device ID',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Hardware Buzzer & LED Config
            Text(
              'Hardware Alarm & Buzzer Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Values automatically sync to ESP32 memory via Firestore',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.volume_up_rounded, color: AppTheme.primaryCyan),
                            SizedBox(width: 10),
                            Text(
                              'Buzzer Alarm Volume',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${_buzzerVolume.toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.primaryCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _buzzerVolume,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      activeColor: AppTheme.primaryCyan,
                      onChanged: (val) {
                        setState(() {
                          _buzzerVolume = val;
                        });
                      },
                      onChangeEnd: (_) => _saveHardwareConfig(),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.timer_rounded, color: AppTheme.primaryCyan),
                            SizedBox(width: 10),
                            Text(
                              'Alarm Cutoff Duration',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${_buzzerDuration.toInt()} sec',
                          style: const TextStyle(
                            color: AppTheme.primaryCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _buzzerDuration,
                      min: 5,
                      max: 120,
                      divisions: 23,
                      activeColor: AppTheme.primaryCyan,
                      onChanged: (val) {
                        setState(() {
                          _buzzerDuration = val;
                        });
                      },
                      onChangeEnd: (_) => _saveHardwareConfig(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notification Toggles
            Text(
              'Notification & Alert Preferences',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications (FCM)'),
                    subtitle: const Text('Receive instant alerts when doses are missed or wrong lid is opened'),
                    secondary: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryCyan),
                    value: _pushEnabled,
                    activeColor: AppTheme.primaryCyan,
                    onChanged: (val) {
                      setState(() {
                        _pushEnabled = val;
                      });
                      _saveHardwareConfig();
                    },
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  SwitchListTile(
                    title: const Text('SMS / Email Emergency Alerts'),
                    subtitle: const Text('Send SMS/Email to caregiver if missed dose exceeds 60 mins'),
                    secondary: const Icon(Icons.contact_phone_rounded, color: AppTheme.primaryTeal),
                    value: _smsEnabled,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (val) {
                      setState(() {
                        _smsEnabled = val;
                      });
                      _saveHardwareConfig();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pairing & Account Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.memory_rounded, color: AppTheme.primaryCyan),
                    title: const Text('Change ESP32 Device Pairing'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DevicePairingScreen()),
                      );
                    },
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppTheme.cardBg,
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await auth.signOut();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: Text(
                'Smart Medicine Companion v1.0.0\nPhase 1 — Reed Switch Verification Engine',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppTheme.neutralGray,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
