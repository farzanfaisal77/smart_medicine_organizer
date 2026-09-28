import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medicine_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/log_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/status_header.dart';
import 'widgets/timeline_widget.dart';
import 'widgets/compartment_grid.dart';
import '../medicine/add_edit_medicine_screen.dart';
import '../logs/logs_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeListeners();
    });
  }

  void _initializeListeners() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.userModel?.uid ?? auth.authUser?.uid;
    final deviceId = auth.userModel?.deviceId ?? '';

    if (uid != null && uid.isNotEmpty) {
      final medProv = Provider.of<MedicineProvider>(context, listen: false);
      medProv.listenToMedicines(uid, deviceId: deviceId);
      Provider.of<LogProvider>(context, listen: false).listenToLogs(
        uid,
        onLogsUpdated: (logs) => medProv.setLogs(logs, deviceId: deviceId),
      );
      if (deviceId.isNotEmpty) {
        Provider.of<DeviceProvider>(context, listen: false).listenToDevice(uid, deviceId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // If user's profile is updated, update listeners if needed
    if (auth.userModel != null) {
      final uid = auth.userModel!.uid;
      final deviceId = auth.userModel!.deviceId;
      final deviceProv = Provider.of<DeviceProvider>(context, listen: false);
      if (deviceProv.deviceState == null || deviceProv.deviceState?.deviceId != deviceId) {
        deviceProv.listenToDevice(uid, deviceId);
      }
    }

    final pages = [
      const _MainDashboardView(),
      const LogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: AppTheme.cardBg,
        indicatorColor: AppTheme.primaryCyan.withOpacity(0.2),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryCyan),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.primaryCyan),
            label: 'Activity Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primaryCyan),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddEditMedicineScreen()),
                );
              },
              backgroundColor: AppTheme.primaryCyan,
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: const Text(
                'Add Medicine',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

class _MainDashboardView extends StatelessWidget {
  const _MainDashboardView();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uid = auth.userModel?.uid;
        final deviceId = auth.userModel?.deviceId ?? '';
        if (uid != null) {
          final medProv = Provider.of<MedicineProvider>(context, listen: false);
          medProv.listenToMedicines(uid, deviceId: deviceId);
          Provider.of<LogProvider>(context, listen: false).listenToLogs(
            uid,
            onLogsUpdated: (logs) => medProv.setLogs(logs, deviceId: deviceId),
          );
          if (deviceId.isNotEmpty) {
            Provider.of<DeviceProvider>(context, listen: false).listenToDevice(uid, deviceId);
          }
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            StatusHeader(),
            SizedBox(height: 20),
            TimelineWidget(),
            SizedBox(height: 20),
            CompartmentGrid(),
            SizedBox(height: 80), // Padding for FloatingActionButton
          ],
        ),
      ),
    );
  }
}
