import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// UNICORN GRADE: Health Connect Availability & Installation Manager.
/// Provides graceful degradation, installation prompts, and cross-platform fallbacks.
class HealthConnectManager extends ChangeNotifier {
  static final HealthConnectManager _instance = HealthConnectManager._internal();
  factory HealthConnectManager() => _instance;
  HealthConnectManager._internal();

  final Health _health = Health();

  // State
  HealthConnectAvailability _availability = HealthConnectAvailability.unknown;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _hasShownInstallPrompt = false;

  // Getters
  HealthConnectAvailability get availability => _availability;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _availability == HealthConnectAvailability.available;
  bool get needsInstall => _availability == HealthConnectAvailability.notInstalled;
  bool get isUnsupported => _availability == HealthConnectAvailability.unsupported;
  String? get errorMessage => _errorMessage;
  bool get hasShownInstallPrompt => _hasShownInstallPrompt;

  // ============================================
  // CORE: AVAILABILITY CHECK
  // ============================================

  /// Initialize and check Health Connect availability.
  /// Call this early in app lifecycle before any health operations.
  Future<HealthConnectAvailability> checkAvailability() async {
    if (_isInitialized) return _availability;

    try {
      // iOS always uses HealthKit - no installation needed
      if (Platform.isIOS) {
        _availability = HealthConnectAvailability.available;
        _isInitialized = true;
        notifyListeners();
        return _availability;
      }

      // Android: Check Health Connect SDK status
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        
        switch (status) {
          case HealthConnectSdkStatus.sdkAvailable:
            _availability = HealthConnectAvailability.available;
            debugPrint('✅ Health Connect: SDK Available');
            break;
          case HealthConnectSdkStatus.sdkUnavailable:
            _availability = HealthConnectAvailability.unsupported;
            _errorMessage = 'Health Connect requires Android 14+ or a compatible device';
            debugPrint('⚠️ Health Connect: SDK Unavailable (Device not supported)');
            break;
          case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
            _availability = HealthConnectAvailability.notInstalled;
            _errorMessage = 'Health Connect needs to be installed or updated';
            debugPrint('📲 Health Connect: Installation Required');
            break;
          case null:
            _availability = HealthConnectAvailability.unsupported;
            _errorMessage = 'Unable to determine Health Connect status';
            debugPrint('⚠️ Health Connect: Status unknown');
            break;
        }
      } else {
        // Desktop/Web - Not supported
        _availability = HealthConnectAvailability.unsupported;
        _errorMessage = 'Health data sync is only available on mobile devices';
      }

      _isInitialized = true;
      notifyListeners();
      return _availability;
    } catch (e) {
      _errorMessage = e.toString();
      _availability = HealthConnectAvailability.error;
      _isInitialized = true;
      debugPrint('🚨 Health Connect Check Error: $e');
      notifyListeners();
      return _availability;
    }
  }

  // ============================================
  // INSTALLATION: PROMPT & REDIRECT
  // ============================================

  /// Opens the Play Store to install Health Connect.
  /// Returns true if the installation flow was initiated.
  Future<bool> installHealthConnect() async {
    if (!Platform.isAndroid) return false;
    
    try {
      await _health.installHealthConnect();
      _hasShownInstallPrompt = true;
      debugPrint('📲 Health Connect: Installation initiated');
      return true;
    } catch (e) {
      debugPrint('🚨 Health Connect Install Error: $e');
      _errorMessage = 'Failed to open Play Store: $e';
      return false;
    }
  }

  /// Marks that the install prompt has been shown (for UI state).
  void markInstallPromptShown() {
    _hasShownInstallPrompt = true;
    notifyListeners();
  }

  /// Re-check availability after returning from Play Store.
  Future<void> recheckAfterInstall() async {
    _isInitialized = false;
    await checkAvailability();
  }

  // ============================================
  // UI HELPERS: DIALOGS & BANNERS
  // ============================================

  /// Shows a beautiful installation dialog matching the app's theme.
  static Future<bool> showInstallDialog(BuildContext context) async {
    final manager = HealthConnectManager();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HealthConnectInstallDialog(manager: manager),
    );

    return result ?? false;
  }

  /// Returns a themed banner widget for embedding in screens.
  static Widget buildStatusBanner({
    required BuildContext context,
    required VoidCallback onInstall,
    VoidCallback? onDismiss,
  }) {
    final manager = HealthConnectManager();
    
    if (manager.isAvailable) return const SizedBox.shrink();

    return _HealthConnectStatusBanner(
      manager: manager,
      onInstall: onInstall,
      onDismiss: onDismiss,
    );
  }
}

// ============================================
// ENUMS & MODELS
// ============================================

enum HealthConnectAvailability {
  unknown,
  available,
  notInstalled,
  unsupported,
  error,
}

// ============================================
// UI COMPONENTS: UNICORN-GRADE DIALOGS
// ============================================

class _HealthConnectInstallDialog extends StatelessWidget {
  final HealthConnectManager manager;

  const _HealthConnectInstallDialog({required this.manager});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A3A2F), Color(0xFF0D1F17)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow effect
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.3),
                      const Color(0xFF059669).withValues(alpha: 0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  size: 48,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Enable Health Sync',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                manager.needsInstall
                    ? 'Install Google Health Connect to sync your glucose readings, steps, and heart rate from your smartwatch and fitness devices.'
                    : 'Health Connect is not supported on this device. You can still use manual entry features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Features list
              if (manager.needsInstall) ...[
                _buildFeatureRow(Icons.watch_rounded, 'Smartwatch sync'),
                _buildFeatureRow(Icons.timeline_rounded, 'Real-time glucose tracking'),
                _buildFeatureRow(Icons.favorite_rounded, 'Heart rate monitoring'),
                const SizedBox(height: 24),
              ],

              // Primary action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (manager.needsInstall) {
                      await manager.installHealthConnect();
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } else {
                      Navigator.of(context).pop(false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    manager.needsInstall ? 'Install Health Connect' : 'Got It',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary action
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  manager.needsInstall ? 'Skip for Now' : 'Close',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF10B981)),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthConnectStatusBanner extends StatelessWidget {
  final HealthConnectManager manager;
  final VoidCallback onInstall;
  final VoidCallback? onDismiss;

  const _HealthConnectStatusBanner({
    required this.manager,
    required this.onInstall,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isInstallable = manager.needsInstall;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isInstallable ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                .withValues(alpha: 0.15),
            (isInstallable ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                .withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isInstallable ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isInstallable ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isInstallable ? Icons.download_rounded : Icons.warning_amber_rounded,
              color: isInstallable ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInstallable ? 'Health Connect Required' : 'Biometric Sync Unavailable',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isInstallable
                      ? 'Install to sync your wearable data'
                      : 'Manual entry mode active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (isInstallable)
            TextButton(
              onPressed: onInstall,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Install',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                size: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}
