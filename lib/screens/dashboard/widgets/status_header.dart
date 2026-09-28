import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/device_provider.dart';
import '../../../theme/app_theme.dart';

class StatusHeader extends StatelessWidget {
  const StatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final device = Provider.of<DeviceProvider>(context);

    final userName = auth.userModel?.name.isNotEmpty == true
        ? auth.userModel!.name
        : 'User';
    final isOnline = device.isOnline;
    final battery = device.batteryLevel;
    final deviceId = auth.userModel?.deviceId ?? 'Unpaired';

    Color batteryColor;
    if (battery > 50) {
      batteryColor = AppTheme.successGreen;
    } else if (battery > 20) {
      batteryColor = AppTheme.warningAmber;
    } else {
      batteryColor = AppTheme.errorRed;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Device: $deviceId',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Battery Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: batteryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: batteryColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      battery > 20 ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                      size: 18,
                      color: batteryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: TextStyle(
                        color: batteryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 12),

          // Connection status pill (Wrapped cleanly to prevent overflows)
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppTheme.successGreen : AppTheme.errorRed,
                  boxShadow: [
                    BoxShadow(
                      color: isOnline
                          ? AppTheme.successGreen.withOpacity(0.6)
                          : AppTheme.errorRed.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline ? 'ESP32 Hardware Online' : 'ESP32 Hardware Offline',
                  style: TextStyle(
                    color: isOnline ? AppTheme.successGreen : AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                isOnline ? 'Synced' : 'Connecting...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
