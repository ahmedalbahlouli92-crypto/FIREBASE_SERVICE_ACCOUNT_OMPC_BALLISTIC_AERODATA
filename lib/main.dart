import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, SystemSound, SystemSoundType;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'services/storage_service.dart';
import 'models/ballistic_record.dart';
import 'services/attachment_helper.dart';
import 'screens/dashboard_tab.dart';
import 'screens/entry_tab.dart';
import 'screens/history_tab.dart';
import 'screens/analysis_recommendation_tab.dart';
import 'screens/consumables_tab.dart';
import 'screens/witness_storage_tab.dart';
import 'screens/executive_reports_tab.dart';
import 'screens/equipment_report_tab.dart';
import 'services/epvat_formula_helper.dart';
import 'services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel, PostgresChangeEvent;
import 'services/app_exit_helper.dart';
import 'services/apk_update_service.dart';
import 'services/report_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize().timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint("Supabase initialization timeout or offline: $e");
  }
  runApp(const OmpcBallisticAeroDataApp());
}

class _SlowBlinkingGreeting extends StatefulWidget {
  final String englishGreeting;
  const _SlowBlinkingGreeting({Key? key, required this.englishGreeting}) : super(key: key);

  @override
  State<_SlowBlinkingGreeting> createState() => _SlowBlinkingGreetingState();
}

class _SlowBlinkingGreetingState extends State<_SlowBlinkingGreeting> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.10).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.10, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withOpacity(0.18),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'السلام عليكم',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(height: 6.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Color(0xFF38BDF8), size: 18.0),
                const SizedBox(width: 8.0),
                Text(
                  widget.englishGreeting,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7DD3FC),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OmpcBallisticAeroDataApp extends StatelessWidget {
  const OmpcBallisticAeroDataApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMPC Ballistic AeroData',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFC4D6EC),
        primaryColor: const Color(0xFF4D99DB),
        cardColor: Colors.white,
        canvasColor: const Color(0xFFC4D6EC),
        dialogBackgroundColor: Colors.white,
        fontFamily: 'Outfit',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4D99DB),
          secondary: Color(0xFF0284C7),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
      ),
      home: const MainShell(),
    );
  }
}

enum UserRole { manager, supervisor, technician, operator, admin }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.manager:
        return 'Manager';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.technician:
        return 'Technician';
      case UserRole.operator:
        return 'Operator';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.manager:
        return const Color(0xFFEC4899); // Magenta / Rose
      case UserRole.supervisor:
        return const Color(0xFFF59E0B); // Amber
      case UserRole.technician:
        return const Color(0xFF06B6D4); // Cyan
      case UserRole.operator:
        return const Color(0xFF10B981); // Emerald Green
      case UserRole.admin:
        return const Color(0xFF6366F1); // Indigo / Purple
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.manager:
        return Icons.verified_user_rounded;
      case UserRole.supervisor:
        return Icons.supervisor_account_rounded;
      case UserRole.technician:
        return Icons.build_circle_rounded;
      case UserRole.operator:
        return Icons.person_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}

UserRole parseUserRole(String? roleStr) {
  if (roleStr == null) return UserRole.operator;
  final clean = roleStr.trim().toLowerCase();
  if (clean == 'manager') return UserRole.manager;
  if (clean == 'supervisor') return UserRole.supervisor;
  if (clean == 'technician') return UserRole.technician;
  if (clean == 'admin') return UserRole.admin;
  return UserRole.operator;
}


final Map<String, dynamic> _defaultRules = {
  'waterproof': {
    'retest_limit': 4,
    'reject_limit': 7,
    'blank_retest_limit': 4,
    'blank_reject_limit': 9,
    'instructions': 'Follow waterproof leakage inspection protocol. Inspect primer and mouth sealings for continuous bubble stream.',
    'calibers': {
      '5.56x45 SS109': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '5.56x45 SS109 Waterproof Test: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '5.56x45 M193': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '5.56x45 M193 Waterproof Test: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '5.56x45 .223 69 grains': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '.223 69gr: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '5.56x45 .223 55 grains': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '.223 55gr: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '5.56x45 .223 77 grains': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '.223 77gr: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '5.56x45 M200 Blank': {'retest_limit': 4, 'reject_limit': 9, 'instructions': '5.56 M200 Blank: Retest if 4 to 8 leaks, Reject if >= 9 leaks.'},
      '7.62x51 M80': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '7.62x51 M80 Waterproof Test: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '7.62x51 .308': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '.308 Win: Max allowable leaks = 3. Retest if 4 to 6. Reject if >= 7.'},
      '7.62x51 M82 Blank': {'retest_limit': 4, 'reject_limit': 9, 'instructions': '7.62 M82 Blank: Retest if 4 to 8 leaks, Reject if >= 9 leaks.'},
      '9x19mm Para': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '9x19mm Para: Retest if 4 to 6 leaks, Reject if >= 7 leaks.'},
      '9x19mm Luger': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '9x19mm Luger: Retest if 4 to 6 leaks, Reject if >= 7 leaks.'},
      '9x19mm Match': {'retest_limit': 3, 'reject_limit': 6, 'instructions': '9x19mm Match: Strict seal inspection. Retest if 3 to 5 leaks, Reject if >= 6.'},
      '9x19mm 124 grains CMJ': {'retest_limit': 4, 'reject_limit': 7, 'instructions': '9x19mm 124gr CMJ: Retest if 4 to 6 leaks, Reject if >= 7 leaks.'},
    }
  },
  'residual_stress': {
    'retest_limit': 1,
    'reject_limit': 3,
    'classification_image': '',
    'instructions': 'Examine splits on Neck Split/crack (I zone), Shoulder Split/Crack (S zone), Body Split/crack (J & K zone), and Head split/crack (L & M zone). No pressure applied.',
    'calibers': {
      '5.56x45 SS109': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '5.56x45 SS109: Retest if 1 to 2 splits/cracks, Reject if >= 3 splits.'},
      '5.56x45 M193': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '5.56x45 M193: Retest if 1 to 2 splits/cracks, Reject if >= 3 splits.'},
      '5.56x45 .223 69 grains': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '.223 69gr: Retest if 1 to 2 splits, Reject if >= 3 splits.'},
      '5.56x45 .223 55 grains': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '.223 55gr: Retest if 1 to 2 splits, Reject if >= 3 splits.'},
      '5.56x45 .223 77 grains': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '.223 77gr: Retest if 1 to 2 splits, Reject if >= 3 splits.'},
      '5.56x45 M200 Blank': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '5.56 M200 Blank: Inspect crimp rosette and case wall for splits.'},
      '7.62x51 M80': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '7.62x51 M80: Retest if 1 to 2 splits/cracks, Reject if >= 3 splits.'},
      '7.62x51 .308': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '.308 Win: Retest if 1 to 2 splits, Reject if >= 3 splits.'},
      '7.62x51 M82 Blank': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '7.62 M82 Blank: Inspect crimp petals and neck for splits.'},
      '9x19mm Para': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '9x19mm Para: Inspect cylindrical case mouth and web for stress cracks.'},
      '9x19mm Luger': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '9x19mm Luger: Inspect case mouth and web for stress cracks.'},
      '9x19mm Match': {'retest_limit': 1, 'reject_limit': 2, 'instructions': '9x19mm Match: High tolerance inspection. Retest if 1 split, Reject if >= 2.'},
      '9x19mm 124 grains CMJ': {'retest_limit': 1, 'reject_limit': 3, 'instructions': '9x19mm 124gr CMJ: Retest if 1 to 2 splits, Reject if >= 3 splits.'},
    }
  },
  'extraction': {
    'instructions': 'Perform pull-out test of bullet and record peak force.',
    'limits': {
      '5.56x45 SS109': 200.0,
      '5.56x45 M193': 165.0,
      '5.56x45 .223 69 grains': 200.0,
      '5.56x45 .223 55 grains': 165.0,
      '5.56x45 .223 77 grains': 200.0,
      '5.56x45 M200 Blank': 0.0,
      '7.62x51 M80': 265.0,
      '7.62x51 .308': 265.0,
      '7.62x51 M82 Blank': 0.0,
      '9x19mm Para': 200.0,
      '9x19mm Luger': 200.0,
      '9x19mm Match': 200.0,
      '9x19mm 124 grains CMJ': 200.0,
    },
    'calibers': {
      '5.56x45 SS109': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N per NATO STANAG 4172.'},
      '5.56x45 M193': {'min_force': 165.0, 'instructions': 'Minimum bullet extraction force is 165 N (MIL-C-9963F).'},
      '5.56x45 .223 69 grains': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N.'},
      '5.56x45 .223 55 grains': {'min_force': 165.0, 'instructions': 'Minimum bullet extraction force is 165 N.'},
      '5.56x45 .223 77 grains': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N.'},
      '5.56x45 M200 Blank': {'min_force': 0.0, 'instructions': 'Blank ammunition: extraction force test is not applicable.'},
      '7.62x51 M80': {'min_force': 265.0, 'instructions': 'Minimum bullet extraction force is 265 N per NATO STANAG 2310.'},
      '7.62x51 .308': {'min_force': 265.0, 'instructions': 'Minimum bullet extraction force is 265 N.'},
      '7.62x51 M82 Blank': {'min_force': 0.0, 'instructions': 'Blank ammunition: extraction force test is not applicable.'},
      '9x19mm Para': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N (NATO STANAG 4090).'},
      '9x19mm Luger': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N.'},
      '9x19mm Match': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N with consistent crimp.'},
      '9x19mm 124 grains CMJ': {'min_force': 200.0, 'instructions': 'Minimum bullet extraction force is 200 N.'},
    }
  },
  'accuracy': {
    'instructions': 'Assess group sizing at target distance and mean velocity bounds.',
    'limits': {
      '5.56x45 SS109': {
        'max_mean_radius': 50.0,
        'max_sd': 180.0,
        'cond_sd': 150.0,
        'vel_min': 915.0,
        'vel_max': 945.0,
        'instructions': '5.56x45 SS109: Target velocity 915 - 945 m/s, Max Mean Radius 50 mm.',
      },
      '5.56x45 M193': {
        'max_mean_radius': 50.0,
        'max_sd': 200.0,
        'cond_sd': 170.0,
        'vel_min': 953.0,
        'vel_max': 980.0,
        'instructions': '5.56x45 M193: Target velocity 953 - 980 m/s, Max Mean Radius 50 mm.',
      },
      '5.56x45 .223 69 grains': {
        'max_mean_radius': 45.0,
        'max_sd': 160.0,
        'cond_sd': 140.0,
        'vel_min': 870.0,
        'vel_max': 905.0,
        'instructions': '.223 69gr: Target velocity 870 - 905 m/s, Max Mean Radius 45 mm.',
      },
      '5.56x45 .223 55 grains': {
        'max_mean_radius': 50.0,
        'max_sd': 200.0,
        'cond_sd': 170.0,
        'vel_min': 950.0,
        'vel_max': 980.0,
        'instructions': '.223 55gr: Target velocity 950 - 980 m/s, Max Mean Radius 50 mm.',
      },
      '5.56x45 .223 77 grains': {
        'max_mean_radius': 40.0,
        'max_sd': 150.0,
        'cond_sd': 130.0,
        'vel_min': 830.0,
        'vel_max': 865.0,
        'instructions': '.223 77gr: Precision match. Target velocity 830 - 865 m/s, Max Mean Radius 40 mm.',
      },
      '5.56x45 M200 Blank': {
        'max_mean_radius': 999.0,
        'max_sd': 999.0,
        'cond_sd': 999.0,
        'vel_min': 0.0,
        'vel_max': 0.0,
        'instructions': 'Blank ammunition: Accuracy test not applicable.',
      },
      '7.62x51 M80': {
        'max_mean_radius': 50.0,
        'max_sd': 200.0,
        'cond_sd': 170.0,
        'vel_min': 823.0,
        'vel_max': 853.0,
        'instructions': '7.62x51 M80: Target velocity 823 - 853 m/s, Max Mean Radius 50 mm.',
      },
      '7.62x51 .308': {
        'max_mean_radius': 45.0,
        'max_sd': 180.0,
        'cond_sd': 150.0,
        'vel_min': 820.0,
        'vel_max': 855.0,
        'instructions': '.308 Win: Target velocity 820 - 855 m/s, Max Mean Radius 45 mm.',
      },
      '7.62x51 M82 Blank': {
        'max_mean_radius': 999.0,
        'max_sd': 999.0,
        'cond_sd': 999.0,
        'vel_min': 0.0,
        'vel_max': 0.0,
        'instructions': 'Blank ammunition: Accuracy test not applicable.',
      },
      '9x19mm Para': {
        'max_mean_radius': 50.0,
        'max_sd': 50.0,
        'cond_sd': 42.5,
        'vel_min': 370.0,
        'vel_max': 400.0,
        'instructions': '9x19mm Para: Target velocity 370 - 400 m/s at 25m, Max Mean Radius 50 mm.',
      },
      '9x19mm Luger': {
        'max_mean_radius': 50.0,
        'max_sd': 50.0,
        'cond_sd': 42.5,
        'vel_min': 370.0,
        'vel_max': 400.0,
        'instructions': '9x19mm Luger: Target velocity 370 - 400 m/s, Max Mean Radius 50 mm.',
      },
      '9x19mm Match': {
        'max_mean_radius': 35.0,
        'max_sd': 40.0,
        'cond_sd': 30.0,
        'vel_min': 365.0,
        'vel_max': 395.0,
        'instructions': '9x19mm Match: Target velocity 365 - 395 m/s, Max Mean Radius 35 mm.',
      },
      '9x19mm 124 grains CMJ': {
        'max_mean_radius': 45.0,
        'max_sd': 45.0,
        'cond_sd': 38.0,
        'vel_min': 360.0,
        'vel_max': 390.0,
        'instructions': '9x19mm 124gr CMJ: Target velocity 360 - 390 m/s, Max Mean Radius 45 mm.',
      },
      'default': {
        'max_mean_radius': 50.0,
        'max_sd': 200.0,
        'cond_sd': 170.0,
        'vel_min': 700.0,
        'vel_max': 900.0,
        'instructions': 'Default Accuracy limits: Max Mean Radius 50 mm, Velocity 700 - 900 m/s.',
      }
    }
  },
  'epvat': {
    'limits_by_caliber': {
      '5.56x45 SS109': {
        '+21': {'vel_min': 915.0, 'vel_max': 945.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 925.0, 'vel_max': 965.0, 'p1_max': 4200.0, 'p2_min': 200.0},
        '-54': {'vel_min': 895.0, 'vel_max': 925.0, 'p1_max': 3600.0, 'p2_min': 180.0},
        'instructions': '5.56x45 SS109: Ensure P1 Chamber <= 3800 bar at +21°C, and P2 Port >= 200 bar.',
      },
      '5.56x45 M193': {
        '+21': {'vel_min': 953.0, 'vel_max': 980.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 960.0, 'vel_max': 995.0, 'p1_max': 4200.0, 'p2_min': 200.0},
        '-54': {'vel_min': 935.0, 'vel_max': 965.0, 'p1_max': 3600.0, 'p2_min': 180.0},
        'instructions': '5.56x45 M193: Target velocity 965 m/s at +21°C. P1 max 3800 bar.',
      },
      '5.56x45 .223 69 grains': {
        '+21': {'vel_min': 870.0, 'vel_max': 905.0, 'p1_max': 3800.0, 'p2_min': 190.0},
        '+52': {'vel_min': 880.0, 'vel_max': 920.0, 'p1_max': 4200.0, 'p2_min': 190.0},
        '-54': {'vel_min': 850.0, 'vel_max': 885.0, 'p1_max': 3600.0, 'p2_min': 170.0},
        'instructions': '.223 69gr Match: P1 max 3800 bar, Velocity 870-905 m/s.',
      },
      '5.56x45 .223 55 grains': {
        '+21': {'vel_min': 950.0, 'vel_max': 980.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 960.0, 'vel_max': 995.0, 'p1_max': 4200.0, 'p2_min': 200.0},
        '-54': {'vel_min': 930.0, 'vel_max': 960.0, 'p1_max': 3600.0, 'p2_min': 180.0},
        'instructions': '.223 55gr: P1 max 3800 bar, Velocity 950-980 m/s.',
      },
      '5.56x45 .223 77 grains': {
        '+21': {'vel_min': 830.0, 'vel_max': 865.0, 'p1_max': 3800.0, 'p2_min': 180.0},
        '+52': {'vel_min': 840.0, 'vel_max': 880.0, 'p1_max': 4200.0, 'p2_min': 180.0},
        '-54': {'vel_min': 810.0, 'vel_max': 845.0, 'p1_max': 3600.0, 'p2_min': 160.0},
        'instructions': '.223 77gr Long Range: P1 max 3800 bar, Velocity 830-865 m/s.',
      },
      '5.56x45 M200 Blank': {
        '+21': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 2100.0, 'p2_min': 100.0},
        '+52': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 2300.0, 'p2_min': 100.0},
        '-54': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 1900.0, 'p2_min': 80.0},
        'instructions': '5.56 M200 Blank: Chamber pressure check only (no bullet velocity).',
      },
      '7.62x51 M80': {
        '+21': {'vel_min': 823.0, 'vel_max': 853.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 835.0, 'vel_max': 870.0, 'p1_max': 4150.0, 'p2_min': 200.0},
        '-54': {'vel_min': 805.0, 'vel_max': 835.0, 'p1_max': 3600.0, 'p2_min': 180.0},
        'instructions': '7.62x51 M80: Velocity 823-853 m/s at +21°C. P1 max 3800 bar.',
      },
      '7.62x51 .308': {
        '+21': {'vel_min': 820.0, 'vel_max': 855.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 830.0, 'vel_max': 870.0, 'p1_max': 4150.0, 'p2_min': 200.0},
        '-54': {'vel_min': 800.0, 'vel_max': 835.0, 'p1_max': 3600.0, 'p2_min': 180.0},
        'instructions': '.308 Win: Velocity 820-855 m/s at +21°C. P1 max 3800 bar.',
      },
      '7.62x51 M82 Blank': {
        '+21': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 2100.0, 'p2_min': 100.0},
        '+52': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 2300.0, 'p2_min': 100.0},
        '-54': {'vel_min': 0.0, 'vel_max': 0.0, 'p1_max': 1900.0, 'p2_min': 80.0},
        'instructions': '7.62 M82 Blank: Pressure check only (no projectile velocity).',
      },
      '9x19mm Para': {
        '+21': {'vel_min': 370.0, 'vel_max': 400.0, 'p1_max': 2350.0, 'p2_min': 100.0},
        '+52': {'vel_min': 380.0, 'vel_max': 415.0, 'p1_max': 2600.0, 'p2_min': 100.0},
        '-54': {'vel_min': 350.0, 'vel_max': 385.0, 'p1_max': 2200.0, 'p2_min': 90.0},
        'instructions': '9x19mm Para: Standard velocity 370-400 m/s at +21°C, P1 max 2350 bar.',
      },
      '9x19mm Luger': {
        '+21': {'vel_min': 370.0, 'vel_max': 400.0, 'p1_max': 2350.0, 'p2_min': 100.0},
        '+52': {'vel_min': 380.0, 'vel_max': 415.0, 'p1_max': 2600.0, 'p2_min': 100.0},
        '-54': {'vel_min': 350.0, 'vel_max': 385.0, 'p1_max': 2200.0, 'p2_min': 90.0},
        'instructions': '9x19mm Luger: Velocity 370-400 m/s at +21°C, P1 max 2350 bar.',
      },
      '9x19mm Match': {
        '+21': {'vel_min': 365.0, 'vel_max': 395.0, 'p1_max': 2300.0, 'p2_min': 100.0},
        '+52': {'vel_min': 375.0, 'vel_max': 410.0, 'p1_max': 2550.0, 'p2_min': 100.0},
        '-54': {'vel_min': 345.0, 'vel_max': 380.0, 'p1_max': 2150.0, 'p2_min': 90.0},
        'instructions': '9x19mm Match: High accuracy handgun test. Velocity 365-395 m/s.',
      },
      '9x19mm 124 grains CMJ': {
        '+21': {'vel_min': 360.0, 'vel_max': 390.0, 'p1_max': 2350.0, 'p2_min': 100.0},
        '+52': {'vel_min': 370.0, 'vel_max': 405.0, 'p1_max': 2600.0, 'p2_min': 100.0},
        '-54': {'vel_min': 340.0, 'vel_max': 375.0, 'p1_max': 2200.0, 'p2_min': 90.0},
        'instructions': '9x19mm 124gr CMJ: Velocity 360-390 m/s at +21°C, P1 max 2350 bar.',
      },
      'default': {
        '+21': {'vel_min': 900.0, 'vel_max': 930.0, 'p1_max': 3800.0, 'p2_min': 200.0},
        '+52': {'vel_min': 910.0, 'vel_max': 950.0, 'p1_max': 4200.0, 'p2_min': 200.0},
        '-54': {'vel_min': 880.0, 'vel_max': 910.0, 'p1_max': 3500.0, 'p2_min': 180.0},
        'instructions': 'General EPVAT limits. P1 Chamber max 3800 bar, P2 Port min 200 bar.',
      },
    },
    'limits': {
      '+21': {
        'vel_min': 900.0,
        'vel_max': 930.0,
        'p1_max': 3800.0,
        'p2_min': 200.0,
      },
      '+52': {
        'vel_min': 910.0,
        'vel_max': 950.0,
        'p1_max': 4200.0,
        'p2_min': 200.0,
      },
      '-54': {
        'vel_min': 880.0,
        'vel_max': 910.0,
        'p1_max': 3500.0,
        'p2_min': 180.0,
      }
    },
    'instructions': 'Ensure P1 (Chamber) does not exceed limits, and P2 (Port) remains above minimums.',
    // Bullet mass (grams) per caliber — used for kinetic energy: E = 0.5 * (m/1000) * v^2
    'bullet_mass_grams': {
      '5.56x45 SS109': 4.0,
      '5.56x45 M193': 3.56,
      '5.56x45 .223 69 grains': 4.47,
      '5.56x45 .223 55 grains': 3.56,
      '5.56x45 .223 77 grains': 4.99,
      '7.62x51 M80': 9.33,
      '7.62x51 .308': 9.33,
      '9x19mm Para': 8.0,
      '9x19mm Luger': 8.04,
      '9x19mm Match': 8.04,
      '9x19mm 124 grains CMJ': 8.04,
    },
    // Extended sentencing options
    'enable_three_sigma_pressure': false,
    'enable_temp_velocity_delta': false,
    'temp_velocity_delta_max': 30.0,
    // Custom sentencing calculations per caliber
    'custom_formulas': {
      '5.56x45 SS109': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': 'NATO STANAG 4172: Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': '3-Sigma Chamber Pressure at +21°C'
        },
        {
          'name': 'P2 Port Mean - 3SD (+21°C)',
          'formula': 'P2_MEAN - 3 * P2_SD',
          'operator': '>=',
          'limit': '180',
          'unit': 'bar',
          'description': 'Port pressure minimum 3-sigma bound at +21°C'
        }
      ],
      'SS109': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': 'NATO STANAG 4172: Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': '3-Sigma Chamber Pressure at +21°C'
        },
        {
          'name': 'P2 Port Mean - 3SD (+21°C)',
          'formula': 'P2_MEAN - 3 * P2_SD',
          'operator': '>=',
          'limit': '180',
          'unit': 'bar',
          'description': 'Port pressure minimum 3-sigma bound at +21°C'
        }
      ],
      '5.56x45 M193': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': 'US MIL-C-9963F: Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': '3-Sigma Chamber Pressure at +21°C'
        },
        {
          'name': 'P2 Port Mean - 3SD (+21°C)',
          'formula': 'P2_MEAN - 3 * P2_SD',
          'operator': '>=',
          'limit': '180',
          'unit': 'bar',
          'description': 'Port pressure minimum 3-sigma bound at +21°C'
        }
      ],
      '7.62x51 M80': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': 'NATO STANAG 2310: Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': '3-Sigma Chamber Pressure at +21°C'
        },
        {
          'name': 'P2 Port Mean - 3SD (+21°C)',
          'formula': 'P2_MEAN - 3 * P2_SD',
          'operator': '>=',
          'limit': '180',
          'unit': 'bar',
          'description': 'Port pressure minimum 3-sigma bound at +21°C'
        }
      ],
      '9x19mm Para': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '2650',
          'unit': 'bar',
          'description': 'NATO STANAG 4090: Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '2650',
          'unit': 'bar',
          'description': '3-Sigma Chamber Pressure at +21°C'
        }
      ],
      '5.56x45 M200 Blank': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '2000',
          'unit': 'bar',
          'description': 'Blank Ammunition Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '2000',
          'unit': 'bar',
          'description': '3-Sigma Blank Chamber Pressure at +21°C'
        }
      ],
      '7.62x51 M82': [
        {
          'name': 'P1 Max Individual (+21°C)',
          'formula': 'P1_MAX_INDIVIDUAL',
          'operator': '<=',
          'limit': '2000',
          'unit': 'bar',
          'description': 'Blank Ammunition Max individual chamber pressure at +21°C'
        },
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '2000',
          'unit': 'bar',
          'description': '3-Sigma Blank Chamber Pressure at +21°C'
        }
      ],
      'default': [
        {
          'name': 'P1 Mean + 3SD (+21°C)',
          'formula': 'P1_MEAN + 3 * P1_SD',
          'operator': '<=',
          'limit': '4200',
          'unit': 'bar',
          'description': 'Statistical upper bound for chamber pressure at +21°C'
        }
      ]
    },
  },
  'cyclic_rate': {
    'weapons': [
      {'name': 'M82', 'type': 'Rifle', 'min': 600, 'max': 850},
      {'name': 'M200', 'type': 'Rifle', 'min': 650, 'max': 900},
      {'name': 'M60', 'type': 'Machine Gun', 'min': 450, 'max': null},
      {'name': 'M240', 'type': 'Machine Gun', 'min': 550, 'max': 650},
      {'name': 'Default Rifle', 'type': 'Rifle', 'min': 550, 'max': 920},
      {'name': 'Default Machine Gun', 'type': 'Machine Gun', 'min': 600, 'max': 1020},
    ]
  },
  'barrel_serial_numbers': [
    'B1001',
    'B1002',
    'B1003',
  ],
  'accuracy_barrels': [
    'ACC-B-101',
    'ACC-B-102',
    'ACC-B-103',
    'ACC-556-01',
    'ACC-762-01',
    'ACC-9MM-01',
    'B1001',
    'B1002',
    'B1003',
  ],
  'accuracy_barrels_by_caliber': {
    '5.56x45 SS109': ['ACC-556-01', 'ACC-B-101', 'B1001'],
    '5.56x45 M193': ['ACC-556-01', 'ACC-B-101', 'B1001'],
    '5.56x45 .223 69 grains': ['ACC-556-01', 'ACC-B-101'],
    '5.56x45 .223 55 grains': ['ACC-556-01', 'ACC-B-101'],
    '5.56x45 .223 77 grains': ['ACC-556-01', 'ACC-B-101'],
    '5.56x45 M200 Blank': ['ACC-556-01'],
    '7.62x51 M80': ['ACC-762-01', 'ACC-B-102', 'B1002'],
    '7.62x51 .308': ['ACC-762-01', 'ACC-B-102'],
    '7.62x51 M82': ['ACC-762-01'],
    '9x19mm Para': ['ACC-9MM-01', 'ACC-B-103', 'B1003'],
    '9x19mm Luger': ['ACC-9MM-01', 'ACC-B-103'],
    '9x19mm Match': ['ACC-9MM-01', 'ACC-B-103'],
    '9x19mm 124 grains CMJ': ['ACC-9MM-01', 'ACC-B-103'],
  },
  'epvat_barrels': [
    'EPVAT-B-201',
    'EPVAT-B-202',
    'EPVAT-B-203',
    'EPV-556-01',
    'EPV-762-01',
    'EPV-9MM-01',
    'B1001',
    'B1002',
    'B1003',
  ],
  'epvat_barrels_by_caliber': {
    '5.56x45 SS109': ['EPV-556-01', 'EPVAT-B-201', 'B1001'],
    '5.56x45 M193': ['EPV-556-01', 'EPVAT-B-201', 'B1001'],
    '5.56x45 .223 69 grains': ['EPV-556-01', 'EPVAT-B-201'],
    '5.56x45 .223 55 grains': ['EPV-556-01', 'EPVAT-B-201'],
    '5.56x45 .223 77 grains': ['EPV-556-01', 'EPVAT-B-201'],
    '5.56x45 M200 Blank': ['EPV-556-01'],
    '7.62x51 M80': ['EPV-762-01', 'EPVAT-B-202', 'B1002'],
    '7.62x51 .308': ['EPV-762-01', 'EPVAT-B-202'],
    '7.62x51 M82': ['EPV-762-01'],
    '9x19mm Para': ['EPV-9MM-01', 'EPVAT-B-203', 'B1003'],
    '9x19mm Luger': ['EPV-9MM-01', 'EPVAT-B-203'],
    '9x19mm Match': ['EPV-9MM-01', 'EPVAT-B-203'],
    '9x19mm 124 grains CMJ': ['EPV-9MM-01', 'EPVAT-B-203'],
  },
  'gp6_transducers': [
    'GP6-001 (PCB 119B)',
    'GP6-002 (PCB 119B)',
    'GP6-003 (Kistler 6215)',
    'GP6-Kistler-8801',
    'GP6-Kistler-8802',
    'GP6-PCB-9901',
  ],
  'gp1_transducers': [
    'GP6-001 (PCB 119B)',
    'GP6-002 (PCB 119B)',
    'GP6-003 (Kistler 6215)',
    'GP6-Kistler-8801',
    'GP6-Kistler-8802',
    'GP6-PCB-9901',
  ],
  'gp6_serials': [
    'GP6-001 (PCB 119B)',
    'GP6-002 (PCB 119B)',
    'GP6-003 (Kistler 6215)',
    'GP6-Kistler-8801',
    'GP6-Kistler-8802',
    'GP6-PCB-9901',
  ],
  'weapons': [
    {'type': 'Steyr AUG A3', 'model': 'Steyr AUG A3', 'serial': 'ST-556-01', 'category': 'Rifle', 'manufacturer': 'Steyr'},
    {'type': 'M16A4 Rifle', 'model': 'M16A4 Rifle', 'serial': 'M16-001', 'category': 'Rifle', 'manufacturer': 'Colt'},
    {'type': 'M4A1 Carbine', 'model': 'M4A1 Carbine', 'serial': 'M4-001', 'category': 'Rifle', 'manufacturer': 'Colt'},
    {'type': 'G3A3 Rifle', 'model': 'G3A3 Rifle', 'serial': 'G3-001', 'category': 'Rifle', 'manufacturer': 'Heckler & Koch'},
    {'type': 'FN SCAR-L', 'model': 'FN SCAR-L', 'serial': 'SCAR-556-01', 'category': 'Rifle', 'manufacturer': 'FN Herstal'},
    {'type': 'M249 SAW', 'model': 'M249 SAW', 'serial': 'SAW-001', 'category': 'Machine Gun', 'manufacturer': 'FN Herstal'},
    {'type': 'M240B', 'model': 'M240B', 'serial': 'M240-001', 'category': 'Machine Gun', 'manufacturer': 'FN Herstal'},
    {'type': 'MG3 Machine Gun', 'model': 'MG3 Machine Gun', 'serial': 'MG3-001', 'category': 'Machine Gun', 'manufacturer': 'Rheinmetall'},
    {'type': 'Beretta 92FS', 'model': 'Beretta 92FS', 'serial': 'BER-92-01', 'category': 'Pistol', 'manufacturer': 'Beretta'},
    {'type': 'Beretta M9 Pistol', 'model': 'Beretta M9 Pistol', 'serial': 'M9-001', 'category': 'Pistol', 'manufacturer': 'Beretta'},
    {'type': 'Glock 17 Gen 5', 'model': 'Glock 17 Gen 5', 'serial': 'GLK-17-01', 'category': 'Pistol', 'manufacturer': 'Glock'},
    {'type': 'Glock 19X', 'model': 'Glock 19X', 'serial': 'GLK-19-01', 'category': 'Pistol', 'manufacturer': 'Glock'},
    {'type': 'SIG Sauer P226', 'model': 'SIG Sauer P226', 'serial': 'SIG-226-01', 'category': 'Pistol', 'manufacturer': 'SIG Sauer'},
    {'type': 'CZ 75B', 'model': 'CZ 75B', 'serial': 'CZ-75-01', 'category': 'Pistol', 'manufacturer': 'CZ'},
    {'type': 'Smith & Wesson M&P9', 'model': 'Smith & Wesson M&P9', 'serial': 'SW-MP9-01', 'category': 'Pistol', 'manufacturer': 'Smith & Wesson'},
  ],
  'gp_transducers': {
    'gp1': [
      'GP1-001 (PCB 119B)',
      'GP1-002 (PCB 119B)',
      'GP1-003 (Kistler 6215)',
      'GP1-004 (Kistler 6215)',
    ],
    'gp2': [
      'GP2-001 (PCB 119B)',
      'GP2-002 (PCB 119B)',
      'GP2-003 (Kistler 6215)',
      'GP6-Kistler-8801',
      'GP6-Kistler-8802',
      'GP6-PCB-9901',
    ],
  },
  'primer_suppliers': [
    'CBC',
    'UNIS "GINIX"',
    'S&B',
    'MD',
  ],
  'propellant_suppliers': [
    'Explosia',
    'Gold Force',
    'PB Clermont',
    'Milan',
  ],
  'propellant_codes': [
    'D073.5',
    'D073.6',
    'SP9',
    'Bofors RP3',
    'PCL 507',
  ],
  'propellant_supplier_codes': {
    'Explosia': ['D-073.4', 'D-073.5', 'D-073.6', 'S060', 'S062', 'S070'],
    'PB Clermont': ['PB-540', 'PCL 507', 'PCL 511'],
    'Gold Force': ['SP9', 'GF-201', 'GF-302'],
    'Milan': ['Bofors RP3', 'RP-15', 'RP-20'],
  },
  'primer_sensitivity': {
    'drop_weight_grams': 55.0,
    'instructions': 'Run-Down / Bruceton Primer Sensitivity Test: Drop steel ball onto primed cases at specified heights.',
    'calibers': {
      '5.56x45 SS109': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 450.0,
        'all_fire_h': 450.0,
        'max_no_fire_height': 75.0,
        'no_fire_h': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '5.56 SS109: HM+5SD <= 450 mm, HM-2SD >= 75 mm.',
      },
      '5.56x45 M193': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 450.0,
        'all_fire_h': 450.0,
        'max_no_fire_height': 75.0,
        'no_fire_h': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '5.56 M193: HM+5SD <= 450 mm, HM-2SD >= 75 mm.',
      },
      '7.62x51 M80': {
        'drop_weight_grams': 111.7,
        'min_all_fire_height': 500.0,
        'all_fire_h': 500.0,
        'max_no_fire_height': 75.0,
        'no_fire_h': 75.0,
        'hbar_min': 160.0,
        'hbar_max': 320.0,
        'max_sd': 65.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '7.62 M80: HM+5SD <= 500 mm, HM-2SD >= 75 mm.',
      },
      '9x19mm Para': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 350.0,
        'all_fire_h': 350.0,
        'max_no_fire_height': 75.0,
        'no_fire_h': 75.0,
        'hbar_min': 140.0,
        'hbar_max': 280.0,
        'max_sd': 55.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '9x19mm Para: HM+5SD <= 350 mm, HM-2SD >= 75 mm.',
      },
      'default': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 450.0,
        'all_fire_h': 450.0,
        'max_no_fire_height': 75.0,
        'no_fire_h': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': 'Standard Primer Sensitivity: HM+5SD <= Limit, HM-2SD >= 75 mm.',
      }
    }
  },
  'function_test': {
    'weapons': [
      'Steyr AUG A3 (SN: ST-556-01)',
      'M16A4 Rifle (SN: M16-001)',
      'M4A1 Carbine (SN: M4-001)',
      'G3A3 Rifle (SN: G3-001)',
      'FN SCAR-L (SN: SCAR-556-01)',
      'M249 SAW (SN: SAW-001)',
      'M240B (SN: M240-001)',
      'MG3 Machine Gun (SN: MG3-001)',
      'Beretta 92FS (SN: BER-92-01)',
      'Beretta M9 Pistol (SN: M9-001)',
      'Glock 17 Gen 5 (SN: GLK-17-01)',
      'Glock 19X (SN: GLK-19-01)',
      'SIG Sauer P226 (SN: SIG-226-01)',
      'CZ 75B (SN: CZ-75-01)',
      'Smith & Wesson M&P9 (SN: SW-MP9-01)',
    ],
    'classification_image': '',
    'calibers': {
      '5.56x45 SS109': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Primer puncture',
            'Misfire',
            'Hangfire',
            'Complete case rupture',
            'Primer through',
            'Primer drop',
            'Loose primer',
            'Pierced primer',
            'No fire',
            'Primer protrusion',
          ],
          'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Hard Extraction',
            'Fail to eject',
            'Fail to Extract',
            'Fail to cock',
            'Split case at points A, B, C, D, E, F, G, H, I or J',
            'Perforated primer',
            'Bolt over case',
          ],
          'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': [
            'Double Feed',
            'Fail to fire',
            'Fail to feed',
            'Fail to chamber',
            'Fail to unlock',
            'Light strike',
          ],
          'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': [
            'Dented case',
            'Scratched case',
            'Damaged bullet',
            'Damaged tip',
          ],
          'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
        },
      },
      '.223 Rem': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Primer puncture',
            'Misfire',
            'Hangfire',
            'Complete case rupture',
            'Primer through',
            'Primer drop',
            'Loose primer',
            'Pierced primer',
            'No fire',
            'Primer protrusion',
          ],
          'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Hard Extraction',
            'Fail to eject',
            'Fail to Extract',
            'Fail to cock',
            'Split case at points A, B, C, D, E, F, G, H, I or J',
            'Perforated primer',
            'Bolt over case',
          ],
          'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': [
            'Double Feed',
            'Fail to fire',
            'Fail to feed',
            'Fail to chamber',
            'Fail to unlock',
            'Light strike',
          ],
          'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': [
            'Dented case',
            'Scratched case',
            'Damaged bullet',
            'Damaged tip',
          ],
          'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
        },
      },
      '7.62x51 M80': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Primer puncture',
            'Misfire',
            'Hangfire',
            'Complete case rupture',
            'Primer through',
            'Primer drop',
            'Loose primer',
            'Pierced primer',
            'No fire',
            'Primer protrusion',
          ],
          'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Hard Extraction',
            'Fail to eject',
            'Fail to Extract',
            'Fail to cock',
            'Split case at points A, B, C, D, E, F, G, H, I or J',
            'Perforated primer',
            'Bolt over case',
          ],
          'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': [
            'Double Feed',
            'Fail to fire',
            'Fail to feed',
            'Fail to chamber',
            'Fail to unlock',
            'Light strike',
          ],
          'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': [
            'Dented case',
            'Scratched case',
            'Damaged bullet',
            'Damaged tip',
          ],
          'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
        },
      },
      '9x19mm Parabellum': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Primer puncture',
            'Misfire',
            'Hangfire',
            'Complete case rupture',
            'Primer through',
            'Primer drop',
            'Loose primer',
            'Pierced primer',
            'No fire',
            'Primer protrusion',
          ],
          'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Hard Extraction',
            'Fail to eject',
            'Fail to Extract',
            'Fail to cock',
            'Split case at points A, B, C, D, E, F, G, H, I or J',
            'Perforated primer',
            'Bolt over case',
          ],
          'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': [
            'Double Feed',
            'Fail to fire',
            'Fail to feed',
            'Fail to chamber',
            'Fail to unlock',
            'Light strike',
          ],
          'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': [
            'Dented case',
            'Scratched case',
            'Damaged bullet',
            'Damaged tip',
          ],
          'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
        },
      },
      '7.62x51 M82': {
        'schema_type': 'categories',
        'categories': {
          'Primer Defect': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Loose primer', 'Pierced primer', 'Blown primer', 'Primer puncture'],
            'description': 'Loose primer, Pierced primer, Blown primer, Primer puncture',
          },
          'Case Defect': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Split case', 'Separated case', 'Ruptured case', 'Dented case', 'Corroded case'],
            'description': 'Split case, Separated case, Ruptured case, Dented case, Corroded case',
          },
          'Weapon Stoppage': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Fail to feed', 'Fail to chamber', 'Fail to fire', 'Fail to extract', 'Fail to eject', 'Double feed', 'Bolt over base'],
            'description': 'Fail to feed, Fail to chamber, Fail to fire, Fail to extract, Fail to eject, Double feed, Bolt over base',
          },
          'Misfire': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Misfire'],
            'description': 'Misfire',
          },
          'Hangfire': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Hangfire'],
            'description': 'Hangfire',
          },
        },
      },
      '5.56x45 M200 Blank': {
        'schema_type': 'categories',
        'categories': {
          'Primer Defect': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Loose primer', 'Pierced primer', 'Blown primer', 'Primer puncture'],
            'description': 'Loose primer, Pierced primer, Blown primer, Primer puncture',
          },
          'Case Defect': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Split case', 'Separated case', 'Ruptured case', 'Dented case', 'Corroded case'],
            'description': 'Split case, Separated case, Ruptured case, Dented case, Corroded case',
          },
          'Weapon Stoppage': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Fail to feed', 'Fail to chamber', 'Fail to fire', 'Fail to extract', 'Fail to eject', 'Double feed', 'Bolt over base'],
            'description': 'Fail to feed, Fail to chamber, Fail to fire, Fail to extract, Fail to eject, Double feed, Bolt over base',
          },
          'Misfire': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Misfire'],
            'description': 'Misfire',
          },
          'Hangfire': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Hangfire'],
            'description': 'Hangfire',
          },
        },
      },
      '5.56x45 M193': {
        'schema_type': 'categories',
        'categories': {
          'Misfire': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Misfire'],
            'description': 'Misfire',
          },
          'Bullet Remaining in bore': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Bullet in Bore'],
            'description': 'Bullet in Bore',
          },
          'Primer Leak': {
            'retest_limit': 0,
            'reject_limit': 1,
            'items': ['Primer Leak'],
            'description': 'Primer Leak',
          },
          'Case casualties': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Ruptured case', 'Separated case', 'Split case body', 'Split case mouth'],
            'description': 'Ruptured case, Separated case, Split case body, Split case mouth',
          },
          'Failure to extract': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Failure to extract'],
            'description': 'Failure to extract',
          },
          'Weapon Stoppage': {
            'retest_limit': 1,
            'reject_limit': 2,
            'items': ['Fail to feed', 'Fail to chamber', 'Fail to lock', 'Fail to fire', 'Fail to unlock', 'Fail to extract', 'Fail to eject', 'Fail to cock'],
            'description': 'Fail to feed, Fail to chamber, Fail to lock, Fail to fire, Fail to unlock, Fail to extract, Fail to eject, Fail to cock',
          },
        },
      },
      '7.62x51 M62 Tracer': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Blind tracer',
          ],
          'description': 'Blown primer, Split case, Bullet lodged in bore, Blind tracer',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': ['Failure to extract', 'Failure to eject', 'Failure to feed', 'Short trace'],
          'description': 'Failure to extract, Failure to eject, Failure to feed, Short trace',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': ['Mild case dent', 'Extractor mark', 'Light primer strike'],
          'description': 'Mild case dent, Extractor mark, Light primer strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': ['Cosmetic markings', 'Scratches'],
          'description': 'Cosmetic markings, Scratches',
        },
      },
      '12.7x99 NATO': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': ['Blown primer', 'Case rupture', 'Split case', 'Bullet in Bore'],
          'description': 'Blown primer, Case rupture, Split case, Bullet lodged in bore',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': ['Failure to extract', 'Failure to eject', 'Misfeed', 'Hangfire'],
          'description': 'Failure to extract, Failure to eject, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': ['Heavy extractor mark', 'Mild dent', 'Primer leak'],
          'description': 'Heavy extractor mark, Mild dent, Primer leak',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': ['Surface scratches', 'Cosmetic imperfections'],
          'description': 'Surface scratches, Cosmetic imperfections',
        },
      },
      'default': {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Split case at points K, L or M',
            'Bullet in Bore',
            'Blown primer',
            'Primer puncture',
            'Misfire',
            'Hangfire',
            'Complete case rupture',
            'Primer through',
            'Primer drop',
            'Loose primer',
            'Pierced primer',
            'No fire',
            'Primer protrusion',
          ],
          'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
        },
        'level2': {
          'max_allowed': 0,
          'retest_limit': 0,
          'reject_limit': 1,
          'items': [
            'Hard Extraction',
            'Fail to eject',
            'Fail to Extract',
            'Fail to cock',
            'Split case at points A, B, C, D, E, F, G, H, I or J',
            'Perforated primer',
            'Bolt over case',
          ],
          'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
        },
        'level3': {
          'max_allowed': 2,
          'retest_limit': 2,
          'reject_limit': 3,
          'items': [
            'Double Feed',
            'Fail to fire',
            'Fail to feed',
            'Fail to chamber',
            'Fail to unlock',
            'Light strike',
          ],
          'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
        },
        'level4': {
          'max_allowed': 5,
          'retest_limit': 4,
          'reject_limit': 6,
          'items': [
            'Dented case',
            'Scratched case',
            'Damaged bullet',
            'Damaged tip',
          ],
          'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
        },
      },
    },
    'level1': {
      'max_allowed': 0,
      'retest_limit': 0,
      'reject_limit': 1,
      'items': [
        'Split case at points K, L or M',
        'Bullet in Bore',
        'Blown primer',
        'Primer puncture',
        'Misfire',
        'Hangfire',
        'Complete case rupture',
        'Primer through',
        'Primer drop',
        'Loose primer',
        'Pierced primer',
        'No fire',
        'Primer protrusion',
      ],
      'description': 'Split case at points K, L or M, Bullet in Bore, Blown primer, Primer puncture, Misfire, Hangfire, Complete case rupture, Primer through, Primer drop, Loose primer, Pierced primer, No fire, Primer protrusion',
    },
    'level2': {
      'max_allowed': 0,
      'retest_limit': 0,
      'reject_limit': 1,
      'items': [
        'Hard Extraction',
        'Fail to eject',
        'Fail to Extract',
        'Fail to cock',
        'Split case at points A, B, C, D, E, F, G, H, I or J',
        'Perforated primer',
        'Bolt over case',
      ],
      'description': 'Hard Extraction, Fail to eject, Fail to Extract, Fail to cock, Split case at points A, B, C, D, E, F, G, H, I or J, Perforated primer, Bolt over case',
    },
    'level3': {
      'max_allowed': 2,
      'retest_limit': 2,
      'reject_limit': 3,
      'items': [
        'Double Feed',
        'Fail to fire',
        'Fail to feed',
        'Fail to chamber',
        'Fail to unlock',
        'Light strike',
      ],
      'description': 'Double Feed, Fail to fire, Fail to feed, Fail to chamber, Fail to unlock, Light strike',
    },
    'level4': {
      'max_allowed': 5,
      'retest_limit': 4,
      'reject_limit': 6,
      'items': [
        'Dented case',
        'Scratched case',
        'Damaged bullet',
        'Damaged tip',
      ],
      'description': 'Dented case, Scratched case, Damaged bullet, Damaged tip',
    },
  },
  'role_permissions': {
    'manager': {
      'can_edit_records': true,
      'can_delete_records': false,
      'can_clear_logs': false,
      'can_export_reports': true,
      'can_manage_rules': true,
    },
    'supervisor': {
      'can_edit_records': true,
      'can_delete_records': false,
      'can_clear_logs': false,
      'can_export_reports': true,
      'can_manage_rules': false,
    },
    'technician': {
      'can_edit_records': false,
      'can_delete_records': false,
      'can_clear_logs': false,
      'can_export_reports': true,
      'can_manage_rules': false,
    },
    'operator': {
      'can_edit_records': false,
      'can_delete_records': false,
      'can_clear_logs': false,
      'can_export_reports': true,
      'can_manage_rules': false,
    },
  },
  'submission_alerts_enabled': true,
};

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final StorageService _storageService = StorageService();
  Timer? _autoSyncTimer;
  Timer? _clockTimer;
  Timer? _welcomeDismissTimer;
  RealtimeChannel? _realtimeChannel;
  DateTime _currentTime = DateTime.now();

  String _formatLiveClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
  
  bool _sidebarHovered = false;
  bool _sidebarPinned = false;
  Map<String, dynamic> _adminRules = {};
  String _selectedRuleTest = 'Waterproof Test';
  bool _submissionAlertsEnabled = true;
  int _activeTabIndex = 0;
  List<BallisticRecord> _records = [];
  List<BallisticRecord> _dailyTestRecords = [];
  List<BallisticRecord> _componentTestRecords = [];
  bool _isLoading = true;
  String _storagePath = '';
  String _base64Logo = '';
  String _base64ReportHeader = '';
  
  UserRole? _currentUserRole;
  String _currentUserEmail = '';
  String _currentModule = 'Lot Acceptance Test';
  String _selectedEntryCaliber = '5.56x45 SS109';
  String _selectedEntryTestName = 'Waterproof Test';

  List<BallisticRecord> get _activeRecords {
    if (_currentModule == 'Lot Acceptance Test') return _records;
    if (_currentModule == 'Component Test') return _componentTestRecords;
    return _dailyTestRecords;
  }
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _opEmailController = TextEditingController();
  final TextEditingController _opPasswordController = TextEditingController();
  final TextEditingController _newOpEmailController = TextEditingController();
  final TextEditingController _newOpPasswordController = TextEditingController();
  final TextEditingController _newOpFullNameController = TextEditingController();
  String _selectedNewUserRole = 'Operator';
  
  // Equipment fleet controllers
  final TextEditingController _newAccuracyBarrelCtrl = TextEditingController();
  final TextEditingController _newEpvatBarrelCtrl = TextEditingController();
  final TextEditingController _newGP6SerialCtrl = TextEditingController();
  final TextEditingController _newGP1TransducerCtrl = TextEditingController();
  final TextEditingController _newPrimerSupplierCtrl = TextEditingController();
  final TextEditingController _newPropellantSupplierCtrl = TextEditingController();
  final TextEditingController _newPropellantCodeCtrl = TextEditingController();
  final TextEditingController _newWeaponTypeInputCtrl = TextEditingController();
  final TextEditingController _newWeaponSerialInputCtrl = TextEditingController();
  String _selectedPropellantCodeSupplier = '';
  String _selectedAdminWeaponType = 'Pistol';
  String _selectedAdminWeaponManufacturer = 'Beretta';
  String _selectedEpvatBarrelCaliber = '5.56x45 SS109';
  String _selectedAccuracyBarrelCaliber = '5.56x45 SS109';

  // Collapsible control module sections (default collapsed so all fit on one page)
  bool _isWorkspaceCardExpanded = false;
  bool _isDiagnosticsCardExpanded = false;
  bool _isPersonnelCardExpanded = false;
  bool _isPermissionsCardExpanded = false;
  bool _isEquipmentCardExpanded = false;
  bool _isRulesCardExpanded = false; // Collapsed by default as requested; admin will open it

  // Report submission real-time alerting & audio chime tracking
  final String _clientSessionId = DateTime.now().microsecondsSinceEpoch.toString();
  final Set<String> _locallySubmittedRecordIds = {};
  final Set<String> _recentlyAlertedRecordIds = {};
  int? _editingFormulaIndex;
  final Map<String, List<String>> _adminWeaponManufacturers = {
    'Pistol': ['Beretta', 'Glock', 'SIG Sauer', 'CZ', 'Smith & Wesson', 'Colt', 'Browning', 'Other'],
    'Rifle': ['Colt', 'FN Herstal', 'Heckler & Koch', 'Steyr', 'Kalashnikov', 'Remington', 'Other'],
    'Carbine': ['Colt', 'M4/M16 Mil-Spec', 'Daniel Defense', 'FN Herstal', 'Heckler & Koch', 'Other'],
    'Submachine Gun': ['Heckler & Koch', 'CZ', 'FN Herstal', 'B&T', 'Uzi', 'Other'],
    'Machine Gun': ['FN Herstal', 'U.S. Ordnance', 'Browning', 'Rheinmetall', 'Other'],
    'Other': ['Other'],
  };
  
  List<Map<String, String>> _operators = [];
  String _loginErrorMessage = '';

  // Rules editor controllers
  final TextEditingController _ruleWaterproofRetestCtrl = TextEditingController();
  final TextEditingController _ruleWaterproofRejectCtrl = TextEditingController();
  final TextEditingController _ruleWaterproofBlankRetestCtrl = TextEditingController();
  final TextEditingController _ruleWaterproofBlankRejectCtrl = TextEditingController();
  final TextEditingController _ruleWaterproofInstructionsCtrl = TextEditingController();
  
  final TextEditingController _ruleStressRetestCtrl = TextEditingController();
  final TextEditingController _ruleStressRejectCtrl = TextEditingController();
  final TextEditingController _ruleStressInstructionsCtrl = TextEditingController();
  
  String _ruleSelectedCaliber = '5.56x45 SS109';
  final TextEditingController _ruleExtMinForceCtrl = TextEditingController();
  final TextEditingController _ruleExtInstructionsCtrl = TextEditingController();
  
  final TextEditingController _ruleAccMaxMeanRadiusCtrl = TextEditingController();
  final TextEditingController _ruleAccMaxSDCtrl = TextEditingController();
  final TextEditingController _ruleAccCondSDCtrl = TextEditingController();
  final TextEditingController _ruleAccMinVelCtrl = TextEditingController();
  final TextEditingController _ruleAccMaxVelCtrl = TextEditingController();
  final TextEditingController _ruleAccInstructionsCtrl = TextEditingController();
  
  String _ruleSelectedEpvatTemp = '+21';
  final TextEditingController _ruleEpvMinVelCtrl = TextEditingController();
  final TextEditingController _ruleEpvMaxVelCtrl = TextEditingController();
  final TextEditingController _ruleEpvMaxP1Ctrl = TextEditingController();
  final TextEditingController _ruleEpvMinP2Ctrl = TextEditingController();
  final TextEditingController _ruleEpvInstructionsCtrl = TextEditingController();

  // EPVAT advanced rule controllers
  String _ruleSelectedEpvatCaliberForMass = '5.56x45 SS109';
  final TextEditingController _ruleEpvBulletMassCtrl = TextEditingController();
  final TextEditingController _ruleEpvTempDeltaMaxCtrl = TextEditingController();
  final TextEditingController _ruleEpvMaxActionTimeCtrl = TextEditingController();
  bool _ruleEpvThreeSigmaEnabled = false;
  bool _ruleEpvTempDeltaEnabled = false;

  // Primer Sensitivity rule controllers
  final TextEditingController _rulePrimerDropWeightCtrl = TextEditingController();
  final TextEditingController _rulePrimerMinAllFireCtrl = TextEditingController();
  final TextEditingController _rulePrimerMaxNoFireCtrl = TextEditingController();
  final TextEditingController _rulePrimerHbarMinCtrl = TextEditingController();
  final TextEditingController _rulePrimerHbarMaxCtrl = TextEditingController();
  final TextEditingController _rulePrimerMaxSDCtrl = TextEditingController();
  final TextEditingController _rulePrimerRetestMisfiresCtrl = TextEditingController();
  final TextEditingController _rulePrimerRejectMisfiresCtrl = TextEditingController();
  final TextEditingController _rulePrimerInstructionsCtrl = TextEditingController();

  // Barrel S.N. rule controller
  final TextEditingController _ruleNewBarrelSNCtrl = TextEditingController();

  // GP Transducers rule controllers
  String _ruleSelectedGPType = 'GP1'; // 'GP1' or 'GP2'
  final TextEditingController _ruleNewGPTransducerCtrl = TextEditingController();

  // EPVAT Custom Formula Registration controllers
  final TextEditingController _ruleNewFormulaNameCtrl = TextEditingController();
  final TextEditingController _ruleNewFormulaExprCtrl = TextEditingController();
  final TextEditingController _ruleNewFormulaLimitCtrl = TextEditingController();
  final TextEditingController _ruleNewFormulaUnitCtrl = TextEditingController(text: 'bar');
  String _ruleNewFormulaOperator = '<=';

  // Weapons rule controllers
  final TextEditingController _ruleNewWeaponNameCtrl = TextEditingController();
  String _ruleNewWeaponType = 'Loose'; // 'Loose' or 'Linked'
  final TextEditingController _ruleNewWeaponMinRpmCtrl = TextEditingController();
  final TextEditingController _ruleNewWeaponMaxRpmCtrl = TextEditingController();

  // Function Test rule controllers
  String _ruleSelectedFuncCaliber = '5.56x45 SS109';
  final TextEditingController _ruleFuncL1MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL1RetestCtrl = TextEditingController();
  final TextEditingController _ruleFuncL1RejectCtrl = TextEditingController();
  final TextEditingController _ruleFuncL1DescCtrl = TextEditingController();

  final TextEditingController _ruleFuncL2MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL2RetestCtrl = TextEditingController();
  final TextEditingController _ruleFuncL2RejectCtrl = TextEditingController();
  final TextEditingController _ruleFuncL2DescCtrl = TextEditingController();

  final TextEditingController _ruleFuncL3MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL3RetestCtrl = TextEditingController();
  final TextEditingController _ruleFuncL3RejectCtrl = TextEditingController();
  final TextEditingController _ruleFuncL3DescCtrl = TextEditingController();

  final TextEditingController _ruleFuncL4MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL4RetestCtrl = TextEditingController();
  final TextEditingController _ruleFuncL4RejectCtrl = TextEditingController();
  final TextEditingController _ruleFuncL4DescCtrl = TextEditingController();

  final Map<String, TextEditingController> _ruleFuncCatRetestCtrls = {};
  final Map<String, TextEditingController> _ruleFuncCatRejectCtrls = {};
  final Map<String, TextEditingController> _ruleFuncCatDescCtrls = {};

  final TextEditingController _ruleNewFuncWeaponCtrl = TextEditingController();

  // Final Lot Acceptance Certificate Template customization controllers
  bool _isCertTemplateCardExpanded = false;
  String _certSelectedCaliber = '5.56x45 SS109';
  final TextEditingController _certSupervisorNameCtrl = TextEditingController();
  final TextEditingController _certManagerNameCtrl = TextEditingController();
  final TextEditingController _certWpSampleCtrl = TextEditingController();
  final TextEditingController _certWpReqCtrl = TextEditingController();
  final TextEditingController _certExtSampleCtrl = TextEditingController();
  final TextEditingController _certExtReqCtrl = TextEditingController();
  final TextEditingController _certAccSampleCtrl = TextEditingController();
  final TextEditingController _certAccReqCtrl = TextEditingController();
  final TextEditingController _certEpvSampleCtrl = TextEditingController();
  final TextEditingController _certEpvReq21Ctrl = TextEditingController();
  final TextEditingController _certEpvReq52Ctrl = TextEditingController();
  final TextEditingController _certEpvReq54Ctrl = TextEditingController();
  final TextEditingController _certEpvFormula21Ctrl = TextEditingController();
  final TextEditingController _certEpvFormula52Ctrl = TextEditingController();
  final TextEditingController _certEpvFormula54Ctrl = TextEditingController();
  final TextEditingController _certFuncSampleCtrl = TextEditingController();
  final TextEditingController _certFuncReqCtrl = TextEditingController();
  final TextEditingController _certRsSampleCtrl = TextEditingController();
  final TextEditingController _certRsReqCtrl = TextEditingController();
  final TextEditingController _certPrimerSampleCtrl = TextEditingController();
  final TextEditingController _certPrimerReqCtrl = TextEditingController();

  void _loadFunctionCaliberRules(String caliber) {
    final func = _adminRules['function_test'] ?? {};
    final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
    final calRules = Map<String, dynamic>.from(calibersMap[caliber] ?? calibersMap['default'] ?? func);

    final l1 = calRules['level1'] ?? func['level1'] ?? {};
    final l2 = calRules['level2'] ?? func['level2'] ?? {};
    final l3 = calRules['level3'] ?? func['level3'] ?? {};
    final l4 = calRules['level4'] ?? func['level4'] ?? {};

    _ruleFuncL1MaxCtrl.text = (l1['max_allowed'] ?? 0).toString();
    _ruleFuncL1RetestCtrl.text = (l1['retest_limit'] ?? 0).toString();
    _ruleFuncL1RejectCtrl.text = (l1['reject_limit'] ?? 1).toString();
    _ruleFuncL1DescCtrl.text = (l1['description'] ?? '').toString();

    _ruleFuncL2MaxCtrl.text = (l2['max_allowed'] ?? 0).toString();
    _ruleFuncL2RetestCtrl.text = (l2['retest_limit'] ?? 0).toString();
    _ruleFuncL2RejectCtrl.text = (l2['reject_limit'] ?? 1).toString();
    _ruleFuncL2DescCtrl.text = (l2['description'] ?? '').toString();

    _ruleFuncL3MaxCtrl.text = (l3['max_allowed'] ?? 2).toString();
    _ruleFuncL3RetestCtrl.text = (l3['retest_limit'] ?? 2).toString();
    _ruleFuncL3RejectCtrl.text = (l3['reject_limit'] ?? 3).toString();
    _ruleFuncL3DescCtrl.text = (l3['description'] ?? '').toString();

    _ruleFuncL4MaxCtrl.text = (l4['max_allowed'] ?? 5).toString();
    _ruleFuncL4RetestCtrl.text = (l4['retest_limit'] ?? 4).toString();
    _ruleFuncL4RejectCtrl.text = (l4['reject_limit'] ?? 6).toString();
    _ruleFuncL4DescCtrl.text = (l4['description'] ?? '').toString();

    // Load category-based rules if applicable
    if (calRules['categories'] is Map) {
      final cats = Map<String, dynamic>.from(calRules['categories'] as Map);
      cats.forEach((catKey, catVal) {
        if (catVal is Map) {
          _ruleFuncCatRetestCtrls.putIfAbsent(catKey, () => TextEditingController()).text = (catVal['retest_limit'] ?? 0).toString();
          _ruleFuncCatRejectCtrls.putIfAbsent(catKey, () => TextEditingController()).text = (catVal['reject_limit'] ?? 1).toString();
          _ruleFuncCatDescCtrls.putIfAbsent(catKey, () => TextEditingController()).text = (catVal['description'] ?? '').toString();
        }
      });
    }
  }

  void _saveCurrentFunctionCaliberRules() {
    final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
    final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
    final existingCalRule = Map<String, dynamic>.from(calibersMap[_ruleSelectedFuncCaliber] ?? {});
    final String schemaType = existingCalRule['schema_type'] ?? 'levels';

    if (schemaType == 'categories') {
      final currentCats = Map<String, dynamic>.from(existingCalRule['categories'] ?? {});
      _ruleFuncCatRetestCtrls.forEach((catKey, ctrl) {
        final catMap = Map<String, dynamic>.from(currentCats[catKey] ?? {});
        catMap['retest_limit'] = int.tryParse(ctrl.text.trim()) ?? 0;
        catMap['reject_limit'] = int.tryParse(_ruleFuncCatRejectCtrls[catKey]?.text.trim() ?? '') ?? 1;
        catMap['description'] = _ruleFuncCatDescCtrls[catKey]?.text.trim() ?? '';
        catMap['items'] = catMap['description'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        currentCats[catKey] = catMap;
      });
      existingCalRule['categories'] = currentCats;
      calibersMap[_ruleSelectedFuncCaliber] = existingCalRule;
    } else {
      final currentRules = {
        'schema_type': 'levels',
        'level1': {
          'max_allowed': int.tryParse(_ruleFuncL1MaxCtrl.text.trim()) ?? 0,
          'retest_limit': int.tryParse(_ruleFuncL1RetestCtrl.text.trim()) ?? 0,
          'reject_limit': int.tryParse(_ruleFuncL1RejectCtrl.text.trim()) ?? 1,
          'description': _ruleFuncL1DescCtrl.text.trim(),
          'items': _ruleFuncL1DescCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        },
        'level2': {
          'max_allowed': int.tryParse(_ruleFuncL2MaxCtrl.text.trim()) ?? 0,
          'retest_limit': int.tryParse(_ruleFuncL2RetestCtrl.text.trim()) ?? 0,
          'reject_limit': int.tryParse(_ruleFuncL2RejectCtrl.text.trim()) ?? 1,
          'description': _ruleFuncL2DescCtrl.text.trim(),
          'items': _ruleFuncL2DescCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        },
        'level3': {
          'max_allowed': int.tryParse(_ruleFuncL3MaxCtrl.text.trim()) ?? 2,
          'retest_limit': int.tryParse(_ruleFuncL3RetestCtrl.text.trim()) ?? 2,
          'reject_limit': int.tryParse(_ruleFuncL3RejectCtrl.text.trim()) ?? 3,
          'description': _ruleFuncL3DescCtrl.text.trim(),
          'items': _ruleFuncL3DescCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        },
        'level4': {
          'max_allowed': int.tryParse(_ruleFuncL4MaxCtrl.text.trim()) ?? 5,
          'retest_limit': int.tryParse(_ruleFuncL4RetestCtrl.text.trim()) ?? 4,
          'reject_limit': int.tryParse(_ruleFuncL4RejectCtrl.text.trim()) ?? 6,
          'description': _ruleFuncL4DescCtrl.text.trim(),
          'items': _ruleFuncL4DescCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        },
      };

      calibersMap[_ruleSelectedFuncCaliber] = currentRules;
      func['level1'] = currentRules['level1'];
      func['level2'] = currentRules['level2'];
      func['level3'] = currentRules['level3'];
      func['level4'] = currentRules['level4'];
    }

    func['calibers'] = calibersMap;
    _adminRules['function_test'] = func;
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _clockTimer?.cancel();
    _welcomeDismissTimer?.cancel();
    _cancelRealtimeSubscription();
    _passwordController.dispose();
    _opEmailController.dispose();
    _opPasswordController.dispose();
    _newOpEmailController.dispose();
    _newOpPasswordController.dispose();
    
    _ruleWaterproofRetestCtrl.dispose();
    _ruleWaterproofRejectCtrl.dispose();
    _ruleWaterproofBlankRetestCtrl.dispose();
    _ruleWaterproofBlankRejectCtrl.dispose();
    _ruleWaterproofInstructionsCtrl.dispose();
    _ruleStressRetestCtrl.dispose();
    _ruleStressRejectCtrl.dispose();
    _ruleStressInstructionsCtrl.dispose();
    _ruleExtMinForceCtrl.dispose();
    _ruleExtInstructionsCtrl.dispose();
    _ruleAccMaxMeanRadiusCtrl.dispose();
    _ruleAccMaxSDCtrl.dispose();
    _ruleAccCondSDCtrl.dispose();
    _ruleAccMinVelCtrl.dispose();
    _ruleAccMaxVelCtrl.dispose();
    _ruleAccInstructionsCtrl.dispose();
    _ruleEpvMinVelCtrl.dispose();
    _ruleEpvMaxVelCtrl.dispose();
    _ruleEpvMaxP1Ctrl.dispose();
    _ruleEpvMinP2Ctrl.dispose();
    _ruleEpvInstructionsCtrl.dispose();
    _ruleEpvBulletMassCtrl.dispose();
    _ruleEpvTempDeltaMaxCtrl.dispose();
    _ruleEpvMaxActionTimeCtrl.dispose();
    _rulePrimerDropWeightCtrl.dispose();
    _rulePrimerMinAllFireCtrl.dispose();
    _rulePrimerMaxNoFireCtrl.dispose();
    _rulePrimerHbarMinCtrl.dispose();
    _rulePrimerHbarMaxCtrl.dispose();
    _rulePrimerMaxSDCtrl.dispose();
    _rulePrimerRetestMisfiresCtrl.dispose();
    _rulePrimerRejectMisfiresCtrl.dispose();
    _rulePrimerInstructionsCtrl.dispose();
    _ruleNewBarrelSNCtrl.dispose();
    _ruleNewGPTransducerCtrl.dispose();
    _ruleNewWeaponNameCtrl.dispose();
    _ruleNewWeaponMinRpmCtrl.dispose();
    _ruleNewWeaponMaxRpmCtrl.dispose();
    _ruleFuncL1MaxCtrl.dispose();
    _ruleFuncL1DescCtrl.dispose();
    _ruleFuncL2MaxCtrl.dispose();
    _ruleFuncL2DescCtrl.dispose();
    _ruleFuncL3MaxCtrl.dispose();
    _ruleFuncL3DescCtrl.dispose();
    _ruleFuncL4MaxCtrl.dispose();
    _ruleFuncL4DescCtrl.dispose();
    _ruleNewFuncWeaponCtrl.dispose();
    
    _newOpFullNameController.dispose();
    _newAccuracyBarrelCtrl.dispose();
    _newEpvatBarrelCtrl.dispose();
    _newGP6SerialCtrl.dispose();
    _newPrimerSupplierCtrl.dispose();
    _newPropellantSupplierCtrl.dispose();
    _newPropellantCodeCtrl.dispose();
    _newWeaponTypeInputCtrl.dispose();
    _newWeaponSerialInputCtrl.dispose();
    
    _ruleNewFormulaNameCtrl.dispose();
    _ruleNewFormulaExprCtrl.dispose();
    _ruleNewFormulaLimitCtrl.dispose();
    _ruleNewFormulaUnitCtrl.dispose();

    _certSupervisorNameCtrl.dispose();
    _certManagerNameCtrl.dispose();
    _certWpSampleCtrl.dispose();
    _certWpReqCtrl.dispose();
    _certExtSampleCtrl.dispose();
    _certExtReqCtrl.dispose();
    _certAccSampleCtrl.dispose();
    _certAccReqCtrl.dispose();
    _certEpvSampleCtrl.dispose();
    _certEpvReq21Ctrl.dispose();
    _certEpvReq52Ctrl.dispose();
    _certEpvReq54Ctrl.dispose();
    _certEpvFormula21Ctrl.dispose();
    _certEpvFormula52Ctrl.dispose();
    _certEpvFormula54Ctrl.dispose();
    _certFuncSampleCtrl.dispose();
    _certFuncReqCtrl.dispose();
    _certRsSampleCtrl.dispose();
    _certRsReqCtrl.dispose();
    _certPrimerSampleCtrl.dispose();
    _certPrimerReqCtrl.dispose();
    
    super.dispose();
  }

  void _syncRulesControllers() {
    if (_adminRules.isEmpty) return;
    
    // Waterproof for selected caliber
    final wp = _adminRules['waterproof'] ?? {};
    final wpCalibers = Map<String, dynamic>.from(wp['calibers'] ?? {});
    final wpCal = Map<String, dynamic>.from(wpCalibers[_ruleSelectedCaliber] ?? {});
    final bool isBlankCal = _ruleSelectedCaliber.contains('M82') || _ruleSelectedCaliber.contains('M200') || _ruleSelectedCaliber.toLowerCase().contains('blank');
    _ruleWaterproofRetestCtrl.text = (wpCal['retest_limit'] ?? (isBlankCal ? (wp['blank_retest_limit'] ?? 4) : (wp['retest_limit'] ?? 4))).toString();
    _ruleWaterproofRejectCtrl.text = (wpCal['reject_limit'] ?? (isBlankCal ? (wp['blank_reject_limit'] ?? 9) : (wp['reject_limit'] ?? 7))).toString();
    _ruleWaterproofBlankRetestCtrl.text = (wp['blank_retest_limit'] ?? 4).toString();
    _ruleWaterproofBlankRejectCtrl.text = (wp['blank_reject_limit'] ?? 9).toString();
    _ruleWaterproofInstructionsCtrl.text = (wpCal['instructions'] ?? wp['instructions'] ?? 'Follow waterproof leakage inspection protocol. Inspect primer and mouth sealings.').toString();
    
    // Residual Stress for selected caliber
    final rs = _adminRules['residual_stress'] ?? {};
    final rsCalibers = Map<String, dynamic>.from(rs['calibers'] ?? {});
    final rsCal = Map<String, dynamic>.from(rsCalibers[_ruleSelectedCaliber] ?? {});
    _ruleStressRetestCtrl.text = (rsCal['retest_limit'] ?? rs['retest_limit'] ?? 1).toString();
    _ruleStressRejectCtrl.text = (rsCal['reject_limit'] ?? rs['reject_limit'] ?? 3).toString();
    _ruleStressInstructionsCtrl.text = (rsCal['instructions'] ?? rs['instructions'] ?? 'Examine splits on Neck, Shoulder, Body, and Head.').toString();
    
    // Extraction Force for selected caliber
    final ext = _adminRules['extraction'] ?? {};
    final extLimits = ext['limits'] ?? {};
    final extCalibers = Map<String, dynamic>.from(ext['calibers'] ?? {});
    final extCal = Map<String, dynamic>.from(extCalibers[_ruleSelectedCaliber] ?? {});
    _ruleExtMinForceCtrl.text = (extCal['min_force'] ?? extLimits[_ruleSelectedCaliber] ?? 200.0).toString();
    _ruleExtInstructionsCtrl.text = (extCal['instructions'] ?? ext['instructions'] ?? 'Perform pull-out test of bullet and record peak force.').toString();
    
    // Accuracy for selected caliber
    final acc = _adminRules['accuracy'] ?? {};
    final accLimits = acc['limits'] ?? {};
    final activeAcc = accLimits[_ruleSelectedCaliber] ?? accLimits['default'] ?? {};
    _ruleAccMaxMeanRadiusCtrl.text = (activeAcc['max_mean_radius'] ?? 50.0).toString();
    _ruleAccMaxSDCtrl.text = (activeAcc['max_sd'] ?? 200.0).toString();
    _ruleAccCondSDCtrl.text = (activeAcc['cond_sd'] ?? 170.0).toString();
    _ruleAccMinVelCtrl.text = (activeAcc['vel_min'] ?? 700.0).toString();
    _ruleAccMaxVelCtrl.text = (activeAcc['vel_max'] ?? 900.0).toString();
    _ruleAccInstructionsCtrl.text = (activeAcc['instructions'] ?? acc['instructions'] ?? 'Assess group sizing at target distance and mean velocity bounds.').toString();
    
    // EPVAT for selected caliber and temp
    final epv = _adminRules['epvat'] ?? {};
    final epvLimitsByCal = Map<String, dynamic>.from(epv['limits_by_caliber'] ?? {});
    final calEpv = Map<String, dynamic>.from(epvLimitsByCal[_ruleSelectedCaliber] ?? {});
    final activeEpv = Map<String, dynamic>.from(calEpv[_ruleSelectedEpvatTemp] ?? (epv['limits']?[_ruleSelectedEpvatTemp] ?? {}));
    _ruleEpvMinVelCtrl.text = (activeEpv['vel_min'] ?? 900.0).toString();
    _ruleEpvMaxVelCtrl.text = (activeEpv['vel_max'] ?? 930.0).toString();
    _ruleEpvMaxP1Ctrl.text = (activeEpv['p1_max'] ?? 3800.0).toString();
    _ruleEpvMinP2Ctrl.text = (activeEpv['p2_min'] ?? 200.0).toString();
    final instructionsByCaliber = Map<String, dynamic>.from(epv['instructions_by_caliber'] ?? {});
    _ruleEpvInstructionsCtrl.text = (instructionsByCaliber[_ruleSelectedCaliber] ?? calEpv['instructions'] ?? epv['instructions'] ?? 'Ensure P1 Chamber does not exceed limits, and P2 Port remains above minimums.').toString();

    // EPVAT Advanced — bullet mass, action time & sentencing flags
    final bulletMassMap = epv['bullet_mass_grams'] ?? {};
    _ruleEpvBulletMassCtrl.text = (bulletMassMap[_ruleSelectedCaliber] ?? bulletMassMap[_ruleSelectedEpvatCaliberForMass] ?? 4.0).toString();
    _ruleEpvMaxActionTimeCtrl.text = (activeEpv['action_time_max'] ?? calEpv['action_time_max'] ?? epv['action_time_max'] ?? 4.0).toString();
    _ruleEpvThreeSigmaEnabled = epv['enable_three_sigma_pressure'] == true;
    _ruleEpvTempDeltaEnabled = epv['enable_temp_velocity_delta'] == true;
    _ruleEpvTempDeltaMaxCtrl.text = (epv['temp_velocity_delta_max'] ?? 30.0).toString();

    // Primer Sensitivity for selected caliber
    final primer = _adminRules['primer_sensitivity'] ?? {};
    final primerCalibers = Map<String, dynamic>.from(primer['calibers'] ?? {});
    final primerCal = Map<String, dynamic>.from(primerCalibers[_ruleSelectedCaliber] ?? primerCalibers['default'] ?? primer);
    _rulePrimerDropWeightCtrl.text = (primerCal['drop_weight_grams'] ?? 55.0).toString();
    _rulePrimerMinAllFireCtrl.text = (primerCal['min_all_fire_height'] ?? 380.0).toString();
    _rulePrimerMaxNoFireCtrl.text = (primerCal['max_no_fire_height'] ?? 75.0).toString();
    _rulePrimerHbarMinCtrl.text = (primerCal['hbar_min'] ?? 150.0).toString();
    _rulePrimerHbarMaxCtrl.text = (primerCal['hbar_max'] ?? 300.0).toString();
    _rulePrimerMaxSDCtrl.text = (primerCal['max_sd'] ?? 60.0).toString();
    _rulePrimerRetestMisfiresCtrl.text = (primerCal['retest_misfires'] ?? 1).toString();
    _rulePrimerRejectMisfiresCtrl.text = (primerCal['reject_misfires'] ?? 2).toString();
    _rulePrimerInstructionsCtrl.text = (primerCal['instructions'] ?? 'Follow Bruceton / Run-down method: Record drop heights and Fire/Misfire results.').toString();

    // Function Test for selected caliber
    _ruleSelectedFuncCaliber = _ruleSelectedCaliber;
    _loadFunctionCaliberRules(_ruleSelectedCaliber);

    // Final Lot Acceptance Certificate template for selected caliber
    _loadCertTemplateForCaliber(_certSelectedCaliber);
  }

  void _loadCertTemplateForCaliber(String caliber) {
    _certSupervisorNameCtrl.text = (_adminRules['supervisor_name'] as String? ?? 'Action Ballistic & Engineering Supervisor').trim();
    _certManagerNameCtrl.text = (_adminRules['manager_name'] as String? ?? 'Acting QC & Engineering Manager').trim();

    final certTemplates = Map<String, dynamic>.from(_adminRules['certificate_templates'] as Map? ?? {});
    Map<String, dynamic>? calConfig;
    for (final k in certTemplates.keys) {
      if (k.toLowerCase() == caliber.toLowerCase() || caliber.toLowerCase().contains(k.toLowerCase())) {
        calConfig = Map<String, dynamic>.from(certTemplates[k] as Map? ?? {});
        break;
      }
    }
    calConfig ??= {};

    _certWpSampleCtrl.text = (calConfig['waterproof_sample'] ?? '20 rounds').toString();
    _certWpReqCtrl.text = (calConfig['waterproof_req'] ?? 'No. of Leaks ≤ 6 Leaks').toString().replaceAll('<br/>', '\n');

    _certExtSampleCtrl.text = (calConfig['extraction_sample'] ?? '20 rounds').toString();
    _certExtReqCtrl.text = (calConfig['extraction_req'] ?? 'Min Force ≥ 200').toString().replaceAll('<br/>', '\n');

    _certAccSampleCtrl.text = (calConfig['accuracy_sample'] ?? '30 rounds').toString();
    _certAccReqCtrl.text = (calConfig['accuracy_req'] ?? 'SD ≤ 200 mm').toString().replaceAll('<br/>', '\n');

    _certEpvSampleCtrl.text = (calConfig['epvat_sample_21'] ?? '90 rounds').toString();
    _certEpvReq21Ctrl.text = (calConfig['epvat_req_21'] ?? 'Max Mean Chamber +3SD ≤ 4450 Bar\nMin Mean Port - 3SD ≥ 1030 Bar').toString().replaceAll('<br/>', '\n');
    _certEpvReq52Ctrl.text = (calConfig['epvat_req_52'] ?? 'Max Mean Chamber ≤ 4550 Bar\nMin Mean Port - 3SD ≥ 1030 Bar').toString().replaceAll('<br/>', '\n');
    _certEpvReq54Ctrl.text = (calConfig['epvat_req_54'] ?? 'Max Mean Chamber ≤ 4550 Bar\nMin Mean Port ≥ 1030 Bar').toString().replaceAll('<br/>', '\n');
    _certEpvFormula21Ctrl.text = (calConfig['epvat_result_formula_21'] ?? '').toString();
    _certEpvFormula52Ctrl.text = (calConfig['epvat_result_formula_52'] ?? '').toString();
    _certEpvFormula54Ctrl.text = (calConfig['epvat_result_formula_54'] ?? '').toString();

    _certFuncSampleCtrl.text = (calConfig['function_sample'] ?? '500 rounds').toString();
    _certFuncReqCtrl.text = (calConfig['function_req'] ?? 'Critical Defect 0\nMajor Defects 3\nLevel 3 Defects 6\nLevel 4 Defects 18').toString().replaceAll('<br/>', '\n');

    _certRsSampleCtrl.text = (calConfig['residual_sample'] ?? '50 rounds').toString();
    _certRsReqCtrl.text = (calConfig['residual_req'] ?? 'No. of cracks I zone ≤ 3 Cracks\nNo. of cracks M, L, K, J & S zone = 0 Crack').toString().replaceAll('<br/>', '\n');

    _certPrimerSampleCtrl.text = (calConfig['primer_sample'] ?? '175 rounds').toString();
    _certPrimerReqCtrl.text = (calConfig['primer_req'] ?? 'H̄+5SD ≤ 450 mm\nH̄-2SD ≥ 75 mm').toString().replaceAll('<br/>', '\n');
  }

  Future<void> _handleSaveCertTemplate() async {
    _adminRules['supervisor_name'] = _certSupervisorNameCtrl.text.trim();
    _adminRules['manager_name'] = _certManagerNameCtrl.text.trim();

    final certTemplates = Map<String, dynamic>.from(_adminRules['certificate_templates'] as Map? ?? {});
    certTemplates[_certSelectedCaliber] = {
      'waterproof_sample': _certWpSampleCtrl.text.trim(),
      'waterproof_req': _certWpReqCtrl.text.trim().replaceAll('\n', '<br/>'),
      'extraction_sample': _certExtSampleCtrl.text.trim(),
      'extraction_req': _certExtReqCtrl.text.trim().replaceAll('\n', '<br/>'),
      'accuracy_sample': _certAccSampleCtrl.text.trim(),
      'accuracy_req': _certAccReqCtrl.text.trim().replaceAll('\n', '<br/>'),
      'epvat_sample_21': _certEpvSampleCtrl.text.trim(),
      'epvat_req_21': _certEpvReq21Ctrl.text.trim().replaceAll('\n', '<br/>'),
      'epvat_req_52': _certEpvReq52Ctrl.text.trim().replaceAll('\n', '<br/>'),
      'epvat_req_54': _certEpvReq54Ctrl.text.trim().replaceAll('\n', '<br/>'),
      'epvat_result_formula_21': _certEpvFormula21Ctrl.text.trim(),
      'epvat_result_formula_52': _certEpvFormula52Ctrl.text.trim(),
      'epvat_result_formula_54': _certEpvFormula54Ctrl.text.trim(),
      'function_sample': _certFuncSampleCtrl.text.trim(),
      'function_req': _certFuncReqCtrl.text.trim().replaceAll('\n', '<br/>'),
      'residual_sample': _certRsSampleCtrl.text.trim(),
      'residual_req': _certRsReqCtrl.text.trim().replaceAll('\n', '<br/>'),
      'primer_sample': _certPrimerSampleCtrl.text.trim(),
      'primer_req': _certPrimerReqCtrl.text.trim().replaceAll('\n', '<br/>'),
    };
    _adminRules['certificate_templates'] = certTemplates;

    await _storageService.saveRules(_adminRules);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Final Lot Acceptance Certificate template for "$_certSelectedCaliber" saved successfully.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSaveRules() async {
    // Collect from controllers into _adminRules map per selected caliber
    final wp = Map<String, dynamic>.from(_adminRules['waterproof'] ?? {});
    final wpCalibers = Map<String, dynamic>.from(wp['calibers'] ?? {});
    wpCalibers[_ruleSelectedCaliber] = {
      'retest_limit': int.tryParse(_ruleWaterproofRetestCtrl.text.trim()) ?? 4,
      'reject_limit': int.tryParse(_ruleWaterproofRejectCtrl.text.trim()) ?? 7,
      'instructions': _ruleWaterproofInstructionsCtrl.text.trim(),
    };
    wp['calibers'] = wpCalibers;
    wp['retest_limit'] = int.tryParse(_ruleWaterproofRetestCtrl.text.trim()) ?? 4;
    wp['reject_limit'] = int.tryParse(_ruleWaterproofRejectCtrl.text.trim()) ?? 7;
    wp['blank_retest_limit'] = int.tryParse(_ruleWaterproofBlankRetestCtrl.text.trim()) ?? 4;
    wp['blank_reject_limit'] = int.tryParse(_ruleWaterproofBlankRejectCtrl.text.trim()) ?? 9;
    wp['instructions'] = _ruleWaterproofInstructionsCtrl.text.trim();
    _adminRules['waterproof'] = wp;
    
    final rs = Map<String, dynamic>.from(_adminRules['residual_stress'] ?? {});
    final rsCalibers = Map<String, dynamic>.from(rs['calibers'] ?? {});
    final currentRsCal = Map<String, dynamic>.from(rsCalibers[_ruleSelectedCaliber] ?? {});
    currentRsCal['retest_limit'] = int.tryParse(_ruleStressRetestCtrl.text.trim()) ?? 1;
    currentRsCal['reject_limit'] = int.tryParse(_ruleStressRejectCtrl.text.trim()) ?? 3;
    currentRsCal['instructions'] = _ruleStressInstructionsCtrl.text.trim();
    rsCalibers[_ruleSelectedCaliber] = currentRsCal;
    rs['calibers'] = rsCalibers;
    rs['retest_limit'] = int.tryParse(_ruleStressRetestCtrl.text.trim()) ?? 1;
    rs['reject_limit'] = int.tryParse(_ruleStressRejectCtrl.text.trim()) ?? 3;
    rs['instructions'] = _ruleStressInstructionsCtrl.text.trim();
    _adminRules['residual_stress'] = rs;
    
    final ext = Map<String, dynamic>.from(_adminRules['extraction'] ?? {});
    final extLimits = Map<String, dynamic>.from(ext['limits'] ?? {});
    final extCalibers = Map<String, dynamic>.from(ext['calibers'] ?? {});
    final minForce = double.tryParse(_ruleExtMinForceCtrl.text.trim()) ?? 200.0;
    extLimits[_ruleSelectedCaliber] = minForce;
    extCalibers[_ruleSelectedCaliber] = {
      'min_force': minForce,
      'instructions': _ruleExtInstructionsCtrl.text.trim(),
    };
    ext['limits'] = extLimits;
    ext['calibers'] = extCalibers;
    ext['instructions'] = _ruleExtInstructionsCtrl.text.trim();
    _adminRules['extraction'] = ext;
    
    final acc = Map<String, dynamic>.from(_adminRules['accuracy'] ?? {});
    final accLimits = Map<String, dynamic>.from(acc['limits'] ?? {});
    final activeAcc = Map<String, dynamic>.from(accLimits[_ruleSelectedCaliber] ?? {});
    activeAcc['max_mean_radius'] = double.tryParse(_ruleAccMaxMeanRadiusCtrl.text.trim()) ?? 50.0;
    activeAcc['max_sd'] = double.tryParse(_ruleAccMaxSDCtrl.text.trim()) ?? 200.0;
    activeAcc['cond_sd'] = double.tryParse(_ruleAccCondSDCtrl.text.trim()) ?? 170.0;
    activeAcc['vel_min'] = double.tryParse(_ruleAccMinVelCtrl.text.trim()) ?? 700.0;
    activeAcc['vel_max'] = double.tryParse(_ruleAccMaxVelCtrl.text.trim()) ?? 900.0;
    activeAcc['instructions'] = _ruleAccInstructionsCtrl.text.trim();
    accLimits[_ruleSelectedCaliber] = activeAcc;
    acc['limits'] = accLimits;
    acc['instructions'] = _ruleAccInstructionsCtrl.text.trim();
    _adminRules['accuracy'] = acc;
    
    final epv = Map<String, dynamic>.from(_adminRules['epvat'] ?? {});
    final epvLimitsByCal = Map<String, dynamic>.from(epv['limits_by_caliber'] ?? {});
    final calEpv = Map<String, dynamic>.from(epvLimitsByCal[_ruleSelectedCaliber] ?? {});
    final activeEpv = Map<String, dynamic>.from(calEpv[_ruleSelectedEpvatTemp] ?? {});
    activeEpv['vel_min'] = double.tryParse(_ruleEpvMinVelCtrl.text.trim()) ?? 900.0;
    activeEpv['vel_max'] = double.tryParse(_ruleEpvMaxVelCtrl.text.trim()) ?? 930.0;
    activeEpv['p1_max'] = double.tryParse(_ruleEpvMaxP1Ctrl.text.trim()) ?? 3800.0;
    activeEpv['p2_min'] = double.tryParse(_ruleEpvMinP2Ctrl.text.trim()) ?? 200.0;
    activeEpv['action_time_max'] = double.tryParse(_ruleEpvMaxActionTimeCtrl.text.trim()) ?? 4.0;
    calEpv['action_time_max'] = double.tryParse(_ruleEpvMaxActionTimeCtrl.text.trim()) ?? 4.0;
    calEpv[_ruleSelectedEpvatTemp] = activeEpv;
    calEpv['instructions'] = _ruleEpvInstructionsCtrl.text.trim();
    epvLimitsByCal[_ruleSelectedCaliber] = calEpv;
    epv['limits_by_caliber'] = epvLimitsByCal;

    final instructionsByCaliber = Map<String, dynamic>.from(epv['instructions_by_caliber'] ?? {});
    instructionsByCaliber[_ruleSelectedCaliber] = _ruleEpvInstructionsCtrl.text.trim();
    epv['instructions_by_caliber'] = instructionsByCaliber;

    // Fallback legacy map
    final epvLimits = Map<String, dynamic>.from(epv['limits'] ?? {});
    epvLimits[_ruleSelectedEpvatTemp] = activeEpv;
    epv['limits'] = epvLimits;
    epv['instructions'] = _ruleEpvInstructionsCtrl.text.trim();

    // Bullet mass
    final bulletMassMap = Map<String, dynamic>.from(epv['bullet_mass_grams'] ?? {});
    bulletMassMap[_ruleSelectedCaliber] = double.tryParse(_ruleEpvBulletMassCtrl.text.trim()) ?? 4.0;
    epv['bullet_mass_grams'] = bulletMassMap;
    epv['enable_three_sigma_pressure'] = _ruleEpvThreeSigmaEnabled;
    epv['enable_temp_velocity_delta'] = _ruleEpvTempDeltaEnabled;
    epv['temp_velocity_delta_max'] = double.tryParse(_ruleEpvTempDeltaMaxCtrl.text.trim()) ?? 30.0;
    _adminRules['epvat'] = epv;

    // Primer Sensitivity
    final primer = Map<String, dynamic>.from(_adminRules['primer_sensitivity'] ?? {});
    final primerCalibers = Map<String, dynamic>.from(primer['calibers'] ?? {});
    final allFireVal = double.tryParse(_rulePrimerMinAllFireCtrl.text.trim()) ?? 450.0;
    final noFireVal = double.tryParse(_rulePrimerMaxNoFireCtrl.text.trim()) ?? 75.0;
    primerCalibers[_ruleSelectedCaliber] = {
      'drop_weight_grams': double.tryParse(_rulePrimerDropWeightCtrl.text.trim()) ?? 55.0,
      'min_all_fire_height': allFireVal,
      'all_fire_h': allFireVal,
      'max_no_fire_height': noFireVal,
      'no_fire_h': noFireVal,
      'hbar_min': double.tryParse(_rulePrimerHbarMinCtrl.text.trim()) ?? 150.0,
      'hbar_max': double.tryParse(_rulePrimerHbarMaxCtrl.text.trim()) ?? 300.0,
      'max_sd': double.tryParse(_rulePrimerMaxSDCtrl.text.trim()) ?? 60.0,
      'retest_misfires': int.tryParse(_rulePrimerRetestMisfiresCtrl.text.trim()) ?? 1,
      'reject_misfires': int.tryParse(_rulePrimerRejectMisfiresCtrl.text.trim()) ?? 2,
      'instructions': _rulePrimerInstructionsCtrl.text.trim(),
    };
    primer['calibers'] = primerCalibers;
    _adminRules['primer_sensitivity'] = primer;
    
    // Function Test
    _ruleSelectedFuncCaliber = _ruleSelectedCaliber;
    _saveCurrentFunctionCaliberRules();

    await _storageService.saveRules(_adminRules);
    setState(() {
      _adminRules = Map<String, dynamic>.from(_adminRules);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Evaluation rules for "$_ruleSelectedCaliber" saved successfully.'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupRealtimeSubscription();
    // Live ticking digital clock timer (Instruction 19)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    // Live background data sync across all users without stopping or refreshing the app
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        _syncRecordsSilently();
        _syncRulesSilently();
      }
    });
  }

  void _setupRealtimeSubscription() {
    SupabaseService.ensureInitialized().then((ok) {
      if (!ok || !mounted) return;
      try {
        _realtimeChannel = SupabaseService.client
            .channel('public:fleet_and_records_live')
            .onBroadcast(
              event: 'report_submitted',
              callback: (payload) {
                if (!mounted) return;
                final senderSession = payload['session_id']?.toString() ?? '';
                if (senderSession == _clientSessionId) return; // Ignore own broadcast
                final recId = payload['rec_id']?.toString() ?? '';
                final user = payload['user']?.toString() ?? 'User';
                final test = payload['test']?.toString() ?? 'Inspection';
                final lot = payload['lot']?.toString() ?? '';
                final alertKey = '${recId}_${user}_$lot';
                if (_recentlyAlertedRecordIds.contains(alertKey)) return;
                _recentlyAlertedRecordIds.add(alertKey);
                _flashRemoteSubmissionAlert(
                  user: user,
                  testName: test,
                  lotNo: lot,
                  status: payload['status']?.toString(),
                );
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: SupabaseService.tableName,
              callback: (payload) {
                if (mounted) {
                  _syncRecordsSilently();
                  _syncRulesSilently();
                  if (payload.eventType == PostgresChangeEvent.insert) {
                    final newRec = payload.newRecord;
                    final recId = newRec['id']?.toString() ?? '';
                    final user = (newRec['operators'] ?? newRec['operator'] ?? 'User').toString();
                    final test = (newRec['test_name'] ?? 'Inspection').toString();
                    final lot = (newRec['lot_no'] ?? '').toString();
                    final status = newRec['status']?.toString();
                    final alertKey = '${recId}_${user}_$lot';
                    if (recId.isNotEmpty && _locallySubmittedRecordIds.contains(recId)) return;
                    if (!_recentlyAlertedRecordIds.contains(alertKey)) {
                      _recentlyAlertedRecordIds.add(alertKey);
                      _flashRemoteSubmissionAlert(
                        user: user,
                        testName: test,
                        lotNo: lot,
                        status: status,
                      );
                    }
                  }
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'admin_control',
              callback: (payload) {
                if (mounted) {
                  _syncRulesSilently();
                }
              },
            )
            .subscribe();
      } catch (e) {
        debugPrint("Notice: Realtime sync fallback to polling: $e");
      }
    });
  }

  void _flashRemoteSubmissionAlert({
    required String user,
    required String testName,
    required String lotNo,
    String? status,
  }) {
    if (!mounted) return;
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF38BDF8), size: 22.0),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$user submitted a report',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Colors.white),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '$testName • Lot: $lotNo${status != null && status.isNotEmpty ? ' • Status: $status' : ''}',
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() => _activeTabIndex = 2);
              },
              icon: const Icon(Icons.table_chart_outlined, size: 14.0, color: Colors.white),
              label: const Text('View in Logs', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelRealtimeSubscription() {
    if (_realtimeChannel != null) {
      try {
        SupabaseService.client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      } catch (_) {}
    }
  }

  Future<void> _syncRulesSilently() async {
    try {
      final cloudRules = await _storageService.loadRules();
      if (cloudRules.isNotEmpty && mounted) {
        setState(() {
          _adminRules = cloudRules;
        });
      }
    } catch (_) {}
  }

  Future<void> _syncRecordsSilently() async {
    try {
      final recordsList = await _storageService.loadRecords(module: 'Lot Acceptance Test');
      final dailyList = await _storageService.loadRecords(module: 'Daily Test');
      final componentList = await _storageService.loadRecords(module: 'Component Test');
      if (mounted) {
        setState(() {
          if (recordsList.isNotEmpty || _records.isEmpty) _records = recordsList;
          if (dailyList.isNotEmpty || _dailyTestRecords.isEmpty) _dailyTestRecords = dailyList;
          if (componentList.isNotEmpty || _componentTestRecords.isEmpty) _componentTestRecords = componentList;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Fast-path: Load assets in parallel
    final logoFuture = rootBundle.load('assets/logo.png').then((bytes) {
      _base64Logo = base64Encode(bytes.buffer.asUint8List());
    }).catchError((e) {
      print("Error loading logo: $e");
    });
    
    final headerFuture = rootBundle.load('assets/report_header.png').then((bytes) {
      _base64ReportHeader = base64Encode(bytes.buffer.asUint8List());
    }).catchError((e) {
      print("Error loading report header: $e");
    });

    try {
      final path = await _storageService.getDirectoryPath();
      final savedModule = _storageService.loadActiveModule();

      // 1. Instant local load (offline-first UI renders immediately without waiting for network)
      final localOps = await _storageService.loadOperators(localOnly: true);
      final localRules = await _storageService.loadRules(localOnly: true);
      final Map<String, dynamic> activeLocalRules = localRules.isEmpty ? Map<String, dynamic>.from(_defaultRules) : localRules;
      
      final localRecordsList = await _storageService.loadRecords(module: 'Lot Acceptance Test', localOnly: true);
      final localDailyList = await _storageService.loadRecords(module: 'Daily Test', localOnly: true);
      final localComponentList = await _storageService.loadRecords(module: 'Component Test', localOnly: true);

      if (mounted) {
        setState(() {
          if (savedModule != null && savedModule.isNotEmpty) {
            _currentModule = savedModule;
          }
          _records = localRecordsList;
          _dailyTestRecords = localDailyList;
          _componentTestRecords = localComponentList;
          _storagePath = path;
          if (localOps.isNotEmpty) _operators = localOps;
          _adminRules = activeLocalRules;
          _submissionAlertsEnabled = activeLocalRules['submission_alerts_enabled'] == true;
          // Unblock UI immediately so the user doesn't experience slow opening
          _isLoading = false;
        });
      }

      await Future.wait([logoFuture, headerFuture]);

      // 2. Cloud data synchronization in parallel in background
      _syncInitialCloudData();
    } catch (e) {
      print("Error loading initial data: $e");
      if (mounted) {
        setState(() {
          _storagePath = 'Error loading directory';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncInitialCloudData() async {
    try {
      final opsList = await _storageService.loadOperators();
      final rules = await _storageService.loadRules();
      final Map<String, dynamic> activeRules = rules.isEmpty ? Map<String, dynamic>.from(_defaultRules) : rules;
      
      bool schemaMigrated = false;

      // Safe schema migration: populate missing sections or keys
      if (activeRules['waterproof'] == null) {
        activeRules['waterproof'] = Map<String, dynamic>.from(_defaultRules['waterproof']);
        schemaMigrated = true;
      } else {
        final wp = Map<String, dynamic>.from(activeRules['waterproof'] as Map);
        if (wp['calibers'] == null) {
          wp['calibers'] = Map<String, dynamic>.from(_defaultRules['waterproof']['calibers']);
          schemaMigrated = true;
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['waterproof']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(wp['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) { cur[k] = v; schemaMigrated = true; } });
          wp['calibers'] = cur;
        }
        activeRules['waterproof'] = wp;
      }
      if (activeRules['residual_stress'] == null) {
        activeRules['residual_stress'] = Map<String, dynamic>.from(_defaultRules['residual_stress']);
        schemaMigrated = true;
      } else {
        final rs = Map<String, dynamic>.from(activeRules['residual_stress'] as Map);
        if (rs['classification_image'] == null) rs['classification_image'] = '';
        if (rs['calibers'] == null) {
          rs['calibers'] = Map<String, dynamic>.from(_defaultRules['residual_stress']['calibers']);
          schemaMigrated = true;
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['residual_stress']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(rs['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) { cur[k] = v; schemaMigrated = true; } });
          rs['calibers'] = cur;
        }
        activeRules['residual_stress'] = rs;
      }
      if (activeRules['extraction'] == null) {
        activeRules['extraction'] = Map<String, dynamic>.from(_defaultRules['extraction']);
        schemaMigrated = true;
      } else {
        final ext = Map<String, dynamic>.from(activeRules['extraction'] as Map);
        if (ext['calibers'] == null) {
          ext['calibers'] = Map<String, dynamic>.from(_defaultRules['extraction']['calibers']);
          schemaMigrated = true;
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['extraction']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(ext['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) { cur[k] = v; schemaMigrated = true; } });
          ext['calibers'] = cur;
        }
        activeRules['extraction'] = ext;
      }
      if (activeRules['accuracy'] == null) {
        activeRules['accuracy'] = Map<String, dynamic>.from(_defaultRules['accuracy']);
        schemaMigrated = true;
      } else {
        final acc = Map<String, dynamic>.from(activeRules['accuracy'] as Map);
        final defaultLimits = Map<String, dynamic>.from(_defaultRules['accuracy']['limits'] ?? {});
        final curLimits = Map<String, dynamic>.from(acc['limits'] ?? {});
        defaultLimits.forEach((k, v) {
          if (!curLimits.containsKey(k)) { curLimits[k] = v; schemaMigrated = true; }
        });
        acc['limits'] = curLimits;
        activeRules['accuracy'] = acc;
      }
      if (activeRules['epvat'] == null) {
        activeRules['epvat'] = Map<String, dynamic>.from(_defaultRules['epvat']);
        schemaMigrated = true;
      } else {
        final epv = Map<String, dynamic>.from(activeRules['epvat'] as Map);
        final defaultFormulas = Map<String, dynamic>.from(_defaultRules['epvat']['custom_formulas'] ?? {});
        if (epv['custom_formulas'] == null || (epv['custom_formulas'] is Map && (epv['custom_formulas'] as Map).isEmpty)) {
          epv['custom_formulas'] = defaultFormulas;
          schemaMigrated = true;
        } else if (epv['custom_formulas'] is Map) {
          final curFormulas = Map<String, dynamic>.from(epv['custom_formulas'] as Map);
          defaultFormulas.forEach((k, v) {
            // ONLY populate if caliber was never registered; preserve deliberate empty list on deletion
            if (!curFormulas.containsKey(k)) {
              curFormulas[k] = v;
              schemaMigrated = true;
            }
          });
          epv['custom_formulas'] = curFormulas;
        }
        if (epv['bullet_mass_grams'] == null) {
          epv['bullet_mass_grams'] = Map<String, dynamic>.from(_defaultRules['epvat']['bullet_mass_grams']);
          schemaMigrated = true;
        }
        if (epv['limits_by_caliber'] == null) {
          epv['limits_by_caliber'] = Map<String, dynamic>.from(_defaultRules['epvat']['limits_by_caliber']);
          schemaMigrated = true;
        } else {
          final defaultLimits = Map<String, dynamic>.from(_defaultRules['epvat']['limits_by_caliber'] ?? {});
          final curLimits = Map<String, dynamic>.from(epv['limits_by_caliber'] as Map);
          defaultLimits.forEach((k, v) {
            if (!curLimits.containsKey(k)) { curLimits[k] = v; schemaMigrated = true; }
          });
          epv['limits_by_caliber'] = curLimits;
        }
        activeRules['epvat'] = epv;
      }
      if (activeRules['cyclic_rate'] == null || activeRules['cyclic_rate']['weapons'] == null) {
        activeRules['cyclic_rate'] = Map<String, dynamic>.from(_defaultRules['cyclic_rate']);
        schemaMigrated = true;
      }
      if (activeRules['barrel_serial_numbers'] == null) {
        activeRules['barrel_serial_numbers'] = List<String>.from(_defaultRules['barrel_serial_numbers']);
        schemaMigrated = true;
      } else {
        activeRules['barrel_serial_numbers'] = List<String>.from(activeRules['barrel_serial_numbers'] as List);
      }
      if (activeRules['accuracy_barrels'] == null) {
        activeRules['accuracy_barrels'] = List<String>.from(_defaultRules['accuracy_barrels']);
        schemaMigrated = true;
      } else {
        activeRules['accuracy_barrels'] = List<String>.from(activeRules['accuracy_barrels'] as List);
      }
      if (activeRules['accuracy_barrels_by_caliber'] == null) {
        activeRules['accuracy_barrels_by_caliber'] = Map<String, dynamic>.from(_defaultRules['accuracy_barrels_by_caliber'] as Map);
        schemaMigrated = true;
      } else {
        activeRules['accuracy_barrels_by_caliber'] = Map<String, dynamic>.from(activeRules['accuracy_barrels_by_caliber'] as Map);
      }
      if (activeRules['epvat_barrels'] == null) {
        activeRules['epvat_barrels'] = List<String>.from(_defaultRules['epvat_barrels']);
        schemaMigrated = true;
      } else {
        activeRules['epvat_barrels'] = List<String>.from(activeRules['epvat_barrels'] as List);
      }
      if (activeRules['epvat_barrels_by_caliber'] == null) {
        activeRules['epvat_barrels_by_caliber'] = Map<String, dynamic>.from(_defaultRules['epvat_barrels_by_caliber'] as Map);
        schemaMigrated = true;
      } else {
        activeRules['epvat_barrels_by_caliber'] = Map<String, dynamic>.from(activeRules['epvat_barrels_by_caliber'] as Map);
      }
      if (activeRules['gp6_serials'] == null) {
        activeRules['gp6_serials'] = List<String>.from(_defaultRules['gp6_serials']);
        schemaMigrated = true;
      } else {
        activeRules['gp6_serials'] = List<String>.from(activeRules['gp6_serials'] as List);
      }
      if (activeRules['weapons'] == null) {
        activeRules['weapons'] = List<Map<String, dynamic>>.from(
          (_defaultRules['weapons'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        schemaMigrated = true;
      } else {
        activeRules['weapons'] = List<Map<String, dynamic>>.from(
          (activeRules['weapons'] as List).map((e) {
            if (e is Map) return Map<String, dynamic>.from(e);
            return {'type': e.toString(), 'serial': ''};
          }),
        );
      }
      if (activeRules['gp_transducers'] == null) {
        activeRules['gp_transducers'] = Map<String, dynamic>.from(_defaultRules['gp_transducers']);
        schemaMigrated = true;
      } else {
        final gp = Map<String, dynamic>.from(activeRules['gp_transducers'] as Map);
        if (gp['gp1'] == null) gp['gp1'] = List<String>.from(_defaultRules['gp_transducers']['gp1']);
        if (gp['gp2'] == null) gp['gp2'] = List<String>.from(_defaultRules['gp_transducers']['gp2']);
        activeRules['gp_transducers'] = gp;
      }
      if (activeRules['function_test'] == null) {
        activeRules['function_test'] = Map<String, dynamic>.from(_defaultRules['function_test']);
        schemaMigrated = true;
      } else {
        final func = Map<String, dynamic>.from(activeRules['function_test'] as Map);
        if (func['weapons'] == null) {
          func['weapons'] = List<String>.from(_defaultRules['function_test']['weapons']);
        }
        if (func['calibers'] == null) {
          func['calibers'] = Map<String, dynamic>.from(_defaultRules['function_test']['calibers']);
        } else {
          final defCalibers = Map<String, dynamic>.from(_defaultRules['function_test']['calibers']);
          final curCalibers = Map<String, dynamic>.from(func['calibers'] as Map);
          defCalibers.forEach((k, v) {
            if (!curCalibers.containsKey(k) || curCalibers[k]['schema_type'] == null) {
              curCalibers[k] = v;
              schemaMigrated = true;
            }
          });
          func['calibers'] = curCalibers;
        }
        if (func['classification_image'] == null) func['classification_image'] = '';
        if (func['level1'] == null) func['level1'] = Map<String, dynamic>.from(_defaultRules['function_test']['level1']);
        if (func['level2'] == null) func['level2'] = Map<String, dynamic>.from(_defaultRules['function_test']['level2']);
        if (func['level3'] == null) func['level3'] = Map<String, dynamic>.from(_defaultRules['function_test']['level3']);
        if (func['level4'] == null) func['level4'] = Map<String, dynamic>.from(_defaultRules['function_test']['level4']);
        activeRules['function_test'] = func;
      }
      if (activeRules['primer_sensitivity'] == null) {
        activeRules['primer_sensitivity'] = Map<String, dynamic>.from(_defaultRules['primer_sensitivity']);
        schemaMigrated = true;
      } else {
        final pr = Map<String, dynamic>.from(activeRules['primer_sensitivity'] as Map);
        if (pr['calibers'] == null) {
          pr['calibers'] = Map<String, dynamic>.from(_defaultRules['primer_sensitivity']['calibers']);
          schemaMigrated = true;
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['primer_sensitivity']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(pr['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) { cur[k] = v; schemaMigrated = true; } });
          pr['calibers'] = cur;
        }
        activeRules['primer_sensitivity'] = pr;
      }

      if (activeRules['role_permissions'] == null) {
        activeRules['role_permissions'] = Map<String, dynamic>.from(_defaultRules['role_permissions']);
        schemaMigrated = true;
      } else {
        final curPerms = Map<String, dynamic>.from(activeRules['role_permissions'] as Map);
        final defPerms = Map<String, dynamic>.from(_defaultRules['role_permissions'] as Map);
        defPerms.forEach((role, perms) {
          if (!curPerms.containsKey(role)) {
            curPerms[role] = Map<String, dynamic>.from(perms as Map);
            schemaMigrated = true;
          } else {
            final curRoleMap = Map<String, dynamic>.from(curPerms[role] as Map);
            (perms as Map).forEach((pk, pv) {
              if (!curRoleMap.containsKey(pk)) { curRoleMap[pk] = pv; schemaMigrated = true; }
            });
            curPerms[role] = curRoleMap;
          }
        });
        activeRules['role_permissions'] = curPerms;
      }
      if (activeRules['submission_alerts_enabled'] == null) {
        activeRules['submission_alerts_enabled'] = true;
      }
      if (activeRules['primer_suppliers'] == null) {
        activeRules['primer_suppliers'] = List<String>.from(_defaultRules['primer_suppliers']);
        schemaMigrated = true;
      } else {
        activeRules['primer_suppliers'] = List<String>.from(activeRules['primer_suppliers'] as List);
      }
      if (activeRules['propellant_suppliers'] == null) {
        activeRules['propellant_suppliers'] = List<String>.from(_defaultRules['propellant_suppliers']);
        schemaMigrated = true;
      } else {
        activeRules['propellant_suppliers'] = List<String>.from(activeRules['propellant_suppliers'] as List);
      }
      if (activeRules['propellant_codes'] == null) {
        activeRules['propellant_codes'] = List<String>.from(_defaultRules['propellant_codes']);
        schemaMigrated = true;
      } else {
        activeRules['propellant_codes'] = List<String>.from(activeRules['propellant_codes'] as List);
      }
      if (activeRules['propellant_supplier_codes'] == null) {
        activeRules['propellant_supplier_codes'] = Map<String, dynamic>.from(_defaultRules['propellant_supplier_codes']);
        schemaMigrated = true;
      } else {
        activeRules['propellant_supplier_codes'] = Map<String, dynamic>.from(activeRules['propellant_supplier_codes'] as Map);
      }

      // Cross-populate and synchronize equipment fleets across all keys:
      final barrelNumbers = List<String>.from(activeRules['barrel_serial_numbers'] as List? ?? []);
      final accBarrels = List<String>.from(activeRules['accuracy_barrels'] as List? ?? []);
      final epvBarrels = List<String>.from(activeRules['epvat_barrels'] as List? ?? []);
      for (final b in accBarrels) {
        if (!barrelNumbers.contains(b)) barrelNumbers.add(b);
      }
      for (final b in epvBarrels) {
        if (!barrelNumbers.contains(b)) barrelNumbers.add(b);
      }
      for (final b in barrelNumbers) {
        if (!accBarrels.contains(b)) accBarrels.add(b);
        if (!epvBarrels.contains(b)) epvBarrels.add(b);
      }
      activeRules['barrel_serial_numbers'] = barrelNumbers;
      activeRules['accuracy_barrels'] = accBarrels;
      activeRules['epvat_barrels'] = epvBarrels;

      final Set<String> unifiedGp6 = {};
      final rawGp6Transducers = activeRules['gp6_transducers'];
      if (rawGp6Transducers is List) {
        for (final e in rawGp6Transducers) {
          final s = e.toString().trim();
          if (s.isNotEmpty) unifiedGp6.add(s);
        }
      }
      for (final key in ['gp1_transducers', 'gp6_serials']) {
        final list = activeRules[key];
        if (list is List) {
          for (final e in list) {
            final s = e.toString().trim();
            if (s.isNotEmpty) unifiedGp6.add(s);
          }
        }
      }
      final rawGpMap = activeRules['gp_transducers'];
      if (rawGpMap is Map) {
        for (final sub in ['gp1', 'gp2']) {
          final list = rawGpMap[sub];
          if (list is List) {
            for (final e in list) {
              final s = e.toString().trim();
              if (s.isNotEmpty) unifiedGp6.add(s);
            }
          }
        }
      }
      if (unifiedGp6.isEmpty) {
        unifiedGp6.addAll(['GP6-001 (PCB 119B)', 'GP6-002 (PCB 119B)', 'GP6-003 (Kistler 6215)', 'GP6-Kistler-8801']);
      }
      final unifiedGp6List = unifiedGp6.toList();
      activeRules['gp6_transducers'] = unifiedGp6List;
      activeRules['gp1_transducers'] = unifiedGp6List;
      activeRules['gp6_serials'] = unifiedGp6List;
      activeRules['gp_transducers'] = {'gp1': unifiedGp6List, 'gp2': unifiedGp6List};

      final fleetWeapons = List<Map<String, dynamic>>.from(
        (activeRules['weapons'] as List? ?? []).map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return {'type': e.toString(), 'serial': '', 'category': 'Rifle'};
        }),
      );
      final funcMap = Map<String, dynamic>.from(activeRules['function_test'] as Map? ?? {});
      final funcWeapons = List<String>.from(funcMap['weapons'] as List? ?? []);
      final cyclicMap = Map<String, dynamic>.from(activeRules['cyclic_rate'] as Map? ?? {});
      final cyclicWeapons = List<Map<String, dynamic>>.from(
        (cyclicMap['weapons'] as List? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
      );

      for (final fw in fleetWeapons) {
        final t = (fw['type'] ?? '').toString();
        final s = (fw['serial'] ?? '').toString();
        final label = s.isNotEmpty ? (t.contains('(SN:') ? t : '$t (SN: $s)') : t;
        if (label.isNotEmpty) {
          if (!funcWeapons.contains(label)) funcWeapons.add(label);
          if (!cyclicWeapons.any((w) => w['name'] == label)) {
            cyclicWeapons.add({
              'name': label,
              'type': fw['category'] == 'Machine Gun' ? 'Linked' : 'Loose',
              'min': 550,
              'max': 950,
            });
          }
        }
      }
      for (final fn in funcWeapons) {
        if (!fleetWeapons.any((w) => (w['type'] == fn || '${w['type']} (SN: ${w['serial']})' == fn))) {
          final snMatch = RegExp(r'\(SN:\s*([^)]+)\)').firstMatch(fn);
          final serial = snMatch?.group(1)?.trim() ?? '';
          final type = snMatch != null ? fn.substring(0, snMatch.start).trim() : fn;
          fleetWeapons.add({
            'type': type,
            'serial': serial,
            'category': fn.toLowerCase().contains('pistol') ? 'Pistol' : (fn.toLowerCase().contains('machine') || fn.toLowerCase().contains('saw') ? 'Machine Gun' : 'Rifle'),
          });
        }
      }
      activeRules['weapons'] = fleetWeapons;
      funcMap['weapons'] = funcWeapons;
      activeRules['function_test'] = funcMap;
      cyclicMap['weapons'] = cyclicWeapons;
      activeRules['cyclic_rate'] = cyclicMap;

      // Only save rules to cloud if schema changes were actually applied
      if (schemaMigrated) {
        unawaited(_storageService.saveRules(activeRules));
      }
      
      // Load all three module records concurrently in parallel
      final recordsFutures = await Future.wait([
        _storageService.loadRecords(module: 'Lot Acceptance Test'),
        _storageService.loadRecords(module: 'Daily Test'),
        _storageService.loadRecords(module: 'Component Test'),
      ]);

      if (mounted) {
        setState(() {
          _records = recordsFutures[0];
          _dailyTestRecords = recordsFutures[1];
          _componentTestRecords = recordsFutures[2];
          _operators = opsList;
          _adminRules = activeRules;
          _submissionAlertsEnabled = activeRules['submission_alerts_enabled'] == true;
        });
      }
    } catch (e) {
      debugPrint("Error syncing initial cloud data: $e");
    }
  }

  bool _hasPermission(String permissionKey) {
    if (_currentUserRole == UserRole.admin) return true;
    if (_currentUserRole == null) return false;
    final roleName = _currentUserRole!.name.toLowerCase();
    final perms = _adminRules['role_permissions'];
    if (perms is Map && perms[roleName] is Map) {
      final roleMap = perms[roleName] as Map;
      return roleMap[permissionKey] == true;
    }
    final defPerms = _defaultRules['role_permissions'];
    if (defPerms is Map && defPerms[roleName] is Map) {
      final roleMap = defPerms[roleName] as Map;
      return roleMap[permissionKey] == true;
    }
    return false;
  }

  Future<void> _handleNewRecord(BallisticRecord record) async {
    // Play submission alert sound
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // Track local ID to avoid alerting self
    if (record.id != null && record.id!.isNotEmpty) {
      _locallySubmittedRecordIds.add(record.id!);
    }

    // Broadcast submission event in real-time to other users
    final opName = record.operators.isNotEmpty ? record.operators : (_currentUserEmail.isNotEmpty ? _currentUserEmail : 'User');
    try {
      _realtimeChannel?.sendBroadcastMessage(
        event: 'report_submitted',
        payload: {
          'session_id': _clientSessionId,
          'rec_id': record.id ?? '',
          'user': opName,
          'test': record.testName,
          'lot': record.lotNo,
          'status': record.status,
          'time': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint("Realtime broadcast note: $e");
    }

    // Optimistic in-memory update: ensures newly submitted record is immediately visible and never disappears
    if (mounted) {
      setState(() {
        if (_currentModule == 'Lot Acceptance Test') {
          _records = [record, ..._records.where((r) => (record.id != null && record.id!.isNotEmpty) ? r.id != record.id : (r.referenceNo != record.referenceNo || r.timestamp != record.timestamp))];
        } else if (_currentModule == 'Component Test') {
          _componentTestRecords = [record, ..._componentTestRecords.where((r) => (record.id != null && record.id!.isNotEmpty) ? r.id != record.id : (r.referenceNo != record.referenceNo || r.timestamp != record.timestamp))];
        } else {
          _dailyTestRecords = [record, ..._dailyTestRecords.where((r) => (record.id != null && record.id!.isNotEmpty) ? r.id != record.id : (r.referenceNo != record.referenceNo || r.timestamp != record.timestamp))];
        }
      });
    }

    try {
      final savedRecord = await _storageService.saveRecord(record, module: _currentModule);
      if (mounted) {
        setState(() {
          if (_currentModule == 'Lot Acceptance Test') {
            _records = [
              savedRecord,
              ..._records.where((r) =>
                  (savedRecord.id != null && savedRecord.id!.isNotEmpty && r.id == savedRecord.id)
                      ? false
                      : (r.timestamp != savedRecord.timestamp || r.lotNo != savedRecord.lotNo || r.testName != savedRecord.testName))
            ];
          } else if (_currentModule == 'Component Test') {
            _componentTestRecords = [
              savedRecord,
              ..._componentTestRecords.where((r) =>
                  (savedRecord.id != null && savedRecord.id!.isNotEmpty && r.id == savedRecord.id)
                      ? false
                      : (r.timestamp != savedRecord.timestamp || r.lotNo != savedRecord.lotNo || r.testName != savedRecord.testName))
            ];
          } else {
            _dailyTestRecords = [
              savedRecord,
              ..._dailyTestRecords.where((r) =>
                  (savedRecord.id != null && savedRecord.id!.isNotEmpty && r.id == savedRecord.id)
                      ? false
                      : (r.timestamp != savedRecord.timestamp || r.lotNo != savedRecord.lotNo || r.testName != savedRecord.testName))
            ];
          }
        });
      }

      final updated = await _storageService.loadRecords(module: _currentModule);
      if (updated.isNotEmpty && mounted) {
        final bool containsSaved = updated.any((r) =>
            (r.id != null && r.id!.isNotEmpty && savedRecord.id != null && r.id == savedRecord.id) ||
            (r.timestamp == savedRecord.timestamp && r.lotNo == savedRecord.lotNo && r.testName == savedRecord.testName));
        final finalList = containsSaved ? updated : [savedRecord, ...updated];

        setState(() {
          if (_currentModule == 'Lot Acceptance Test') {
            _records = finalList;
          } else if (_currentModule == 'Component Test') {
            _componentTestRecords = finalList;
          } else {
            _dailyTestRecords = finalList;
          }
        });
      }
    } catch (e) {
      debugPrint("Error saving/loading record: $e");
    }

    if (_submissionAlertsEnabled && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
          ),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Submitted Successfully',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: Colors.white),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      '${record.testName} • Lot: ${record.lotNo} • Status: ${record.status} by ${record.operators}',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  setState(() => _activeTabIndex = 2);
                },
                icon: const Icon(Icons.table_chart_outlined, size: 14.0, color: Colors.white),
                label: const Text('View in Logs', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  minimumSize: Size.zero,
                ),
              ),
              const SizedBox(width: 4.0),
              TextButton(
                onPressed: () {
                  setState(() {
                    _submissionAlertsEnabled = false;
                    _adminRules['submission_alerts_enabled'] = false;
                  });
                  _storageService.saveRules(_adminRules);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child: const Text('Mute', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0)),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openFolder() {
    _storageService.openLogsDirectory();
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  void _checkForApkUpdate() async {
    // Only check and display APK update notifications on Android mobile/tablet (APK app).
    // Never show APK update notifications on Windows desktop or Web.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final updateInfo = await ApkUpdateService.checkForUpdate();
      if (updateInfo != null && updateInfo.hasUpdate && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            title: Row(
              children: const [
                Icon(Icons.system_update_rounded, color: Color(0xFF38BDF8), size: 26),
                SizedBox(width: 10),
                Text('New Version Available', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A newer version of OMPC Ballistic AeroData is available for download.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Version:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          Text('v${updateInfo.currentVersion}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Latest Version:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          Text('v${updateInfo.latestVersion}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (updateInfo.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Release Notes:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(updateInfo.releaseNotes, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (updateInfo.apkDownloadUrl.isNotEmpty) {
                    ReportHelper.instance.openUrl(url: updateInfo.apkDownloadUrl);
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download APK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("APK update check error: $e");
    }
  }

  void _authenticateAdmin() {
    final password = _passwordController.text.trim();
    print("ADMIN LOGIN ATTEMPT: Password: '$password'");
    if (password == 'admin123') {
      print("ADMIN LOGIN SUCCESS");
      setState(() {
        _currentUserRole = UserRole.admin;
        _currentUserEmail = 'System Administrator';
        _activeTabIndex = 0; // Dashboard
        _loginErrorMessage = '';
      });
      _passwordController.clear();
      _showWelcomeNotification('System Administrator', 'Administrator');
      _checkForApkUpdate();
    } else {
      print("ADMIN LOGIN FAILED: Expected 'admin123', got '$password'");
      setState(() {
        _loginErrorMessage = 'Authentication failed. Please verify credentials.';
      });
    }
  }

  void _showWelcomeNotification(String name, String roleName) {
    if (!mounted) return;
    _welcomeDismissTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        _welcomeDismissTimer = Timer(const Duration(seconds: 5), () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Container(
            width: math.min(520.0, MediaQuery.of(context).size.width * 0.94),
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
            decoration: BoxDecoration(
              color: const Color(0xFF162B46),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: const Color(0xFF06B6D4), width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.35),
                  blurRadius: 32.0,
                  spreadRadius: 2.0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 40.0,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF06B6D4), width: 2.0),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 48.0),
                ),
                const SizedBox(height: 18.0),
                _SlowBlinkingGreeting(englishGreeting: _getTimeBasedGreeting()),
                const SizedBox(height: 18.0),
                Text(
                  'WELCOME, ${name.toUpperCase()}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: const Color(0xFF0284C7)),
                  ),
                  child: Text(
                    'ACCESS GRANTED • ROLE: ${roleName.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'OMPC BALLISTIC AERODATA PORTAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton.icon(
                  onPressed: () {
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18.0),
                  label: const Text(
                    'ENTER PORTAL',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    elevation: 4.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _welcomeDismissTimer?.cancel();
      _welcomeDismissTimer = null;
    });
  }

  void _authenticateOperator() {
    final usernameInput = _opEmailController.text.trim().toLowerCase();
    final password = _opPasswordController.text.trim();
    print("USER LOGIN ATTEMPT: Username: '$usernameInput', Password: '$password'");
    print("Current registered operators: $_operators");
    
    if (usernameInput.isEmpty || password.isEmpty) {
      print("USER LOGIN FAILED: Empty fields");
      setState(() {
        _loginErrorMessage = 'Please enter both username and password.';
      });
      return;
    }

    // Direct Administrator Login Check
    if ((usernameInput == 'admin' || usernameInput == 'administrator') && password == 'admin123') {
      print("ADMIN LOGIN SUCCESS via User Login");
      setState(() {
        _currentUserRole = UserRole.admin;
        _currentUserEmail = 'System Administrator';
        _activeTabIndex = 0;
        _loginErrorMessage = '';
      });
      _opEmailController.clear();
      _opPasswordController.clear();
      _showWelcomeNotification('System Administrator', 'Administrator');
      _checkForApkUpdate();
      return;
    }

    final matchIndex = _operators.indexWhere((op) {
      final opName = (op['email'] ?? op['username'] ?? '').toLowerCase();
      return opName == usernameInput && op['password'] == password;
    });

    if (matchIndex != -1) {
      final matchedOp = _operators[matchIndex];
      final displayName = (matchedOp['name'] != null && matchedOp['name']!.isNotEmpty)
          ? matchedOp['name']!
          : (matchedOp['email'] ?? matchedOp['username'] ?? usernameInput);
      final roleStr = matchedOp['role'] ?? 'operator';
      final role = parseUserRole(roleStr);
      print("USER LOGIN SUCCESS: $displayName as ${role.label}");
      setState(() {
        _currentUserRole = role;
        _currentUserEmail = displayName;
        _activeTabIndex = 0; // Open Dashboard tab by default for all users
        _loginErrorMessage = '';
      });
      _opEmailController.clear();
      _opPasswordController.clear();
      _showWelcomeNotification(displayName, role.label);
      _checkForApkUpdate();
    } else {
      print("USER LOGIN FAILED: No matching credentials");
      setState(() {
        _loginErrorMessage = 'Authentication failed. Please check your username and password.';
      });
    }
  }

  Future<void> _registerNewOperator() async {
    final username = _newOpEmailController.text.trim();
    final password = _newOpPasswordController.text.trim();
    final fullName = _newOpFullNameController.text.trim();
    final role = _selectedNewUserRole.toLowerCase();
    
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Username and password cannot be empty.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (username.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Username must be at least 2 characters.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final exists = _operators.any((op) => (op['email'] ?? op['username'] ?? '').toLowerCase() == username.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User already registered with this username.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      await _storageService.saveOperator(
        username,
        password,
        role: role,
        name: fullName.isNotEmpty ? fullName : username,
      );
      final updated = await _storageService.loadOperators();
      setState(() {
        _operators = updated;
      });
      _newOpEmailController.clear();
      _newOpPasswordController.clear();
      _newOpFullNameController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User "$username" (${role.toUpperCase()}) registered successfully.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save user: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleDeleteOperator(String identifier) async {
    try {
      await _storageService.deleteOperator(identifier);
      final updated = await _storageService.loadOperators();
      setState(() {
        _operators = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operator "$identifier" deleted.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete operator: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _confirmDeleteOperator(String identifier, String displayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Confirm Deletion', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete user "$displayName" (@$identifier)? This user will no longer be able to log in.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDeleteOperator(identifier);
            },
            child: const Text('Delete User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEditOperatorDialog(Map<String, dynamic> op) {
    final oldUsername = op['email'] ?? '';
    final usernameCtrl = TextEditingController(text: oldUsername);
    final passwordCtrl = TextEditingController(text: op['password'] ?? '');
    final nameCtrl = TextEditingController(text: op['name'] ?? '');
    String selectedRole = (op['role'] ?? 'operator').toString().toLowerCase();

    final roles = ['admin', 'manager', 'supervisor', 'technician', 'operator'];
    if (!roles.contains(selectedRole)) selectedRole = 'operator';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
            ),
            title: Row(
              children: const [
                Icon(Icons.manage_accounts_rounded, color: Color(0xFF38BDF8), size: 24),
                SizedBox(width: 10),
                Text('Edit User Credentials', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: usernameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Username / Email',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Assigned Role', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          items: roles.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final newEmail = usernameCtrl.text.trim();
                  final newPassword = passwordCtrl.text.trim();
                  final newName = nameCtrl.text.trim();
                  if (newEmail.isEmpty || newPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username and password cannot be empty.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  try {
                    await _storageService.editOperator(
                      oldUsername,
                      newEmail: newEmail,
                      newPassword: newPassword,
                      newRole: selectedRole,
                      newName: newName,
                    );
                    final updated = await _storageService.loadOperators();
                    setState(() {
                      _operators = updated;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('User "$newEmail" updated successfully.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update user: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteRecord(BallisticRecord record) async {
    setState(() {
      if (_currentModule == 'Lot Acceptance Test') {
        _records.removeWhere((r) => 
          (record.id != null && record.id!.isNotEmpty && r.id == record.id) ||
          (r.timestamp == record.timestamp && 
          r.lotNumber == record.lotNumber && 
          r.produced == record.produced &&
          r.defects == record.defects)
        );
      } else if (_currentModule == 'Component Test') {
        _componentTestRecords.removeWhere((r) => 
          (record.id != null && record.id!.isNotEmpty && r.id == record.id) ||
          (r.timestamp == record.timestamp && 
          r.lotNumber == record.lotNumber && 
          r.produced == record.produced &&
          r.defects == record.defects)
        );
      } else {
        _dailyTestRecords.removeWhere((r) => 
          (record.id != null && record.id!.isNotEmpty && r.id == record.id) ||
          (r.timestamp == record.timestamp && 
          (r.lotNumber == record.lotNumber || (record.hopperNo.isNotEmpty && r.hopperNo == record.hopperNo)) && 
          r.produced == record.produced &&
          r.defects == record.defects)
        );
      }
    });
    try {
      await _storageService.deleteRecord(record, module: _currentModule);
      final recordsToSave = _currentModule == 'Lot Acceptance Test' ? _records : (_currentModule == 'Component Test' ? _componentTestRecords : _dailyTestRecords);
      await _storageService.overwriteRecords(recordsToSave, module: _currentModule);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quality entry deleted and synchronized across all platforms.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete record: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      // Reload in case of error
      final currentRecords = await _storageService.loadRecords(module: _currentModule);
      setState(() {
        if (_currentModule == 'Lot Acceptance Test') {
          _records = currentRecords;
        } else if (_currentModule == 'Component Test') {
          _componentTestRecords = currentRecords;
        } else {
          _dailyTestRecords = currentRecords;
        }
      });
    }
  }

  Future<void> _handleEditRecord(BallisticRecord original, BallisticRecord updated) async {
    setState(() {
      void updateInList(List<BallisticRecord> list) {
        for (int i = 0; i < list.length; i++) {
          final r = list[i];
          final matchesId = original.id != null && original.id!.isNotEmpty && r.id == original.id;
          final matchesLot = original.lotNo.isNotEmpty &&
              r.lotNo == original.lotNo &&
              r.testName == original.testName &&
              r.caliber == original.caliber;
          final matchesAttributes = r.timestamp == original.timestamp &&
              r.lotNumber == original.lotNumber &&
              r.produced == original.produced &&
              r.defects == original.defects;
          if (matchesId || matchesAttributes) {
            list[i] = updated;
          } else if (matchesLot && updated.status != original.status) {
            list[i] = list[i].copyWith(status: updated.status);
          }
        }
      }

      if (_currentModule == 'Lot Acceptance Test') {
        updateInList(_records);
      } else if (_currentModule == 'Component Test') {
        updateInList(_componentTestRecords);
      } else {
        updateInList(_dailyTestRecords);
      }
    });

    try {
      await _storageService.updateRecord(original, updated, module: _currentModule);
      final recordsToSave = _currentModule == 'Lot Acceptance Test' ? _records : (_currentModule == 'Component Test' ? _componentTestRecords : _dailyTestRecords);
      await _storageService.overwriteRecords(recordsToSave, module: _currentModule);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quality inspection record updated successfully.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update record: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      final currentRecords = await _storageService.loadRecords(module: _currentModule);
      if (mounted) {
        setState(() {
          if (_currentModule == 'Lot Acceptance Test') {
            _records = currentRecords;
          } else if (_currentModule == 'Component Test') {
            _componentTestRecords = currentRecords;
          } else {
            _dailyTestRecords = currentRecords;
          }
        });
      }
    }
  }

  Future<void> _handleClearDailyTestLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF344D6E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(color: Color(0xFF1E3A8A)),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8.0),
            Text('Clear Daily Test Logs', style: TextStyle(color: Colors.white, fontSize: 18.0)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently clear all inspection records for Daily Test? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF8E96A3), fontSize: 14.0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E96A3))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _dailyTestRecords.clear();
    });
    try {
      await _storageService.clearRecords(module: 'Daily Test');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily Test inspection logs cleared successfully.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear Daily Test logs: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      final currentRecords = await _storageService.loadRecords(module: 'Daily Test');
      setState(() {
        _dailyTestRecords = currentRecords;
      });
    }
  }

  Future<void> _handleClearDashboardRecords(String scope) async {
    setState(() {
      if (scope == 'all') {
        _records.clear();
        _dailyTestRecords.clear();
      } else {
        if (_currentModule == 'Lot Acceptance Test') {
          _records.clear();
        } else {
          _dailyTestRecords.clear();
        }
      }
    });

    try {
      if (scope == 'all') {
        await _storageService.clearRecords(module: 'Lot Acceptance Test');
        await _storageService.clearRecords(module: 'Daily Test');
      } else {
        await _storageService.clearRecords(module: _currentModule);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(scope == 'all'
                ? 'All test records have been cleared across all modules. App is ready for fresh input.'
                : '$_currentModule records cleared successfully. App is ready for fresh input.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear records: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      final lotRecords = await _storageService.loadRecords(module: 'Lot Acceptance Test');
      final dailyRecords = await _storageService.loadRecords(module: 'Daily Test');
      if (mounted) {
        setState(() {
          _records = lotRecords;
          _dailyTestRecords = dailyRecords;
        });
      }
    }
  }

  Widget _buildClassificationImageSection(String testKey, String title) {
    final imageBase64 = (_adminRules[testKey]?['classification_image'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 16.0, color: Color(0xFF6366F1)),
              const SizedBox(width: 8.0),
              Text(
                title,
                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          const Text(
            'Upload a visual reference picture / classification chart. This image will appear in reports and preview guides.',
            style: TextStyle(fontSize: 11.0, color: Color(0xFF8E96A3)),
          ),
          const SizedBox(height: 12.0),
          if (imageBase64.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180.0),
                width: double.infinity,
                color: Colors.black.withOpacity(0.4),
                child: Image.memory(
                  base64Decode(imageBase64.contains(',') ? imageBase64.split(',')[1] : imageBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Invalid image format', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.0)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final res = await getAttachmentHelper().pickFileAsBase64(accept: 'image/*');
                    if (res != null && res['data'] != null) {
                      setState(() {
                        final testMap = Map<String, dynamic>.from(_adminRules[testKey] ?? {});
                        testMap['classification_image'] = res['data'];
                        _adminRules[testKey] = testMap;
                      });
                      await _storageService.saveRules(_adminRules);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 14.0),
                  label: const Text('Replace Picture', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF06B6D4),
                    side: const BorderSide(color: Color(0xFF06B6D4)),
                  ),
                ),
                const SizedBox(width: 8.0),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() {
                      final testMap = Map<String, dynamic>.from(_adminRules[testKey] ?? {});
                      testMap['classification_image'] = '';
                      _adminRules[testKey] = testMap;
                    });
                    await _storageService.saveRules(_adminRules);
                  },
                  icon: const Icon(Icons.delete_outline, size: 14.0, color: Color(0xFFEF4444)),
                  label: const Text('Remove Picture', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () async {
                final res = await getAttachmentHelper().pickFileAsBase64(accept: 'image/*');
                if (res != null && res['data'] != null) {
                  setState(() {
                    final testMap = Map<String, dynamic>.from(_adminRules[testKey] ?? {});
                    testMap['classification_image'] = res['data'];
                    _adminRules[testKey] = testMap;
                  });
                  await _storageService.saveRules(_adminRules);
                }
              },
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16.0),
              label: const Text('Upload Classification Picture', style: TextStyle(fontSize: 12.0)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessPortal() {
    return Scaffold(
      backgroundColor: const Color(0xFF263852),
      body: Stack(
        children: [
          Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2F4464),
              Color(0xFF263852),
              Color(0xFF213146),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450.0),
              padding: const EdgeInsets.all(32.0),
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF344D6E),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    blurRadius: 36.0,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C415E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5), width: 2.0),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 150.0,
                        width: 150.0,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  const Text(
                    'OMPC BALLISTIC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Text(
                    'AERODATA PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  
                  // Unified Personnel & Admin Login Portal
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C415E),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.badge_outlined, color: Color(0xFF38BDF8), size: 20.0),
                            SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'User Login',
                                style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        const Text(
                          'Enter your username and password to access quality trials, log entries, and laboratory analytics.',
                          style: TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                        const SizedBox(height: 16.0),
                        
                        TextField(
                          controller: _opEmailController,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                          onSubmitted: (_) => _authenticateOperator(),
                          decoration: InputDecoration(
                            hintText: 'Username or Email',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8), size: 16.0),
                            filled: true,
                            fillColor: const Color(0xFF263852),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        TextField(
                          controller: _opPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                          onSubmitted: (_) => _authenticateOperator(),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 16.0),
                            filled: true,
                            fillColor: const Color(0xFF263852),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
                          ),
                        ),
                        if (_loginErrorMessage.isNotEmpty) ...[
                          const SizedBox(height: 8.0),
                          Text(
                            _loginErrorMessage,
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11.5),
                          ),
                        ],
                        const SizedBox(height: 12.0),
                        SizedBox(
                          width: double.infinity,
                          height: 38.0,
                          child: ElevatedButton(
                            onPressed: _authenticateOperator,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                            ),
                            child: const Text('Enter Laboratory Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: IconButton(
              icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 28.0),
              tooltip: 'Exit Application',
              onPressed: () => _confirmExitApp(context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmExitApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF344D6E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 24.0),
            SizedBox(width: 10.0),
            Text('Exit Application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to close OMPC Ballistic AeroData?',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14.0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              closeApplication();
            },
            child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. CONTROL PANEL TAB WIDGET
  Widget _buildControlPanelTab() {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Lab Control & Settings',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 3.0),
                    Text(
                      'Native desktop hooks, personnel roles, equipment fleet, and ballistic rules',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isWorkspaceCardExpanded = false;
                        _isDiagnosticsCardExpanded = false;
                        _isPersonnelCardExpanded = false;
                        _isPermissionsCardExpanded = false;
                        _isEquipmentCardExpanded = false;
                        _isRulesCardExpanded = false;
                        _isCertTemplateCardExpanded = false;
                      });
                    },
                    icon: const Icon(Icons.unfold_less_rounded, size: 16.0, color: Color(0xFF475569)),
                    label: const Text('Collapse All', style: TextStyle(color: Color(0xFF475569), fontSize: 12.0, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isWorkspaceCardExpanded = true;
                        _isDiagnosticsCardExpanded = true;
                        _isPersonnelCardExpanded = true;
                        _isPermissionsCardExpanded = true;
                        _isEquipmentCardExpanded = true;
                        _isRulesCardExpanded = true;
                        _isCertTemplateCardExpanded = true;
                      });
                    },
                    icon: const Icon(Icons.unfold_more_rounded, size: 16.0, color: Color(0xFF0284C7)),
                    label: const Text('Expand All', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12.0, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Workspace Settings Card
              _buildWorkspaceSettingsCard(isDesktop),
              const SizedBox(height: 12.0),

              // 2. Diagnostics Card
              _buildDiagnosticsCard(),

              // 3. Personnel & Role Management (Admin only)
              if (_currentUserRole == UserRole.admin) ...[
                const SizedBox(height: 12.0),
                _buildOperatorManagementCard(double.infinity),
                const SizedBox(height: 12.0),
                // 4. Role Permissions & Access Matrix (Admin only)
                _buildRolePermissionsCard(double.infinity),
                const SizedBox(height: 12.0),
                // 5. Equipment Fleet & Round Tracking (Admin only)
                _buildEquipmentFleetCard(double.infinity),
              ],

              // 6. Rules Management (Admin only or authorized roles)
              if (_currentUserRole == UserRole.admin || _hasPermission('can_manage_rules')) ...[
                const SizedBox(height: 12.0),
                _buildRulesManagementCard(double.infinity),
                const SizedBox(height: 12.0),
                _buildCertificateTemplateCard(double.infinity),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSettingsCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isWorkspaceCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isWorkspaceCardExpanded = !_isWorkspaceCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF4D99DB)),
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: Color(0xFF0284C7), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'Active Workspace Logs',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: Icon(_isWorkspaceCardExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF0284C7)),
                  onPressed: () => setState(() => _isWorkspaceCardExpanded = !_isWorkspaceCardExpanded),
                ),
              ],
            ),
          ),
          if (_isWorkspaceCardExpanded) ...[
            const SizedBox(height: 12.0),
            const Text(
              'Ballistic trial outcomes are logged to high-fidelity CSV files. These files are stored in your documents directory for integration with other analytics suites.',
              style: TextStyle(fontSize: 13.0, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FB),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFD6E4F0)),
              ),
              child: Text(
                'Target Path:\n$_storagePath',
                style: const TextStyle(fontSize: 12.0, color: Color(0xFF0284C7), fontFamily: 'JetBrainsMono'),
              ),
            ),
            const SizedBox(height: 16.0),
            if (isDesktop && _currentUserRole == UserRole.admin)
              SizedBox(
                width: double.infinity,
                height: 40.0,
                child: ElevatedButton.icon(
                  onPressed: _openFolder,
                  icon: const Icon(Icons.folder_open, size: 18.0),
                  label: const Text('Open Logs Directory'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4D99DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ),
            if (_currentUserRole == UserRole.admin) ...[
              const SizedBox(height: 10.0),
              SizedBox(
                width: double.infinity,
                height: 40.0,
                child: OutlinedButton.icon(
                  onPressed: _handleClearDailyTestLogs,
                  icon: const Icon(Icons.delete_sweep, size: 18.0, color: Color(0xFFEF4444)),
                  label: const Text('Clear Daily Test Logs', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isDiagnosticsCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isDiagnosticsCardExpanded = !_isDiagnosticsCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF4D99DB)),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'System Diagnostics',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: Icon(_isDiagnosticsCardExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF0284C7)),
                  onPressed: () => setState(() => _isDiagnosticsCardExpanded = !_isDiagnosticsCardExpanded),
                ),
              ],
            ),
          ),
          if (_isDiagnosticsCardExpanded) ...[
            const SizedBox(height: 16.0),
            _buildDiagnosticItem('Operating System', kIsWeb ? 'BROWSER' : Platform.operatingSystem.toUpperCase()),
            _buildDiagnosticItem('Execution Host', 'Flutter Native Engine'),
            _buildDiagnosticItem('Database Source', 'Local Flatfile (CSV)'),
            _buildDiagnosticItem('Daily Report File', _storageService.getDailyFileName()),
            _buildDiagnosticItem('Local Port Binding', 'None (Native Embedded Storage)'),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatorManagementCard(double width) {
    int managerCount = 0;
    int supervisorCount = 0;
    int technicianCount = 0;
    int operatorCount = 0;

    for (var op in _operators) {
      final role = (op['role'] ?? 'operator').toLowerCase();
      if (role == 'manager') managerCount++;
      else if (role == 'supervisor') supervisorCount++;
      else if (role == 'technician') technicianCount++;
      else operatorCount++;
    }

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isPersonnelCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isPersonnelCardExpanded = !_isPersonnelCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF4D99DB)),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF0284C7), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'Personnel & Role Management (4 Tiers)',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: Icon(_isPersonnelCardExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF0284C7)),
                  onPressed: () => setState(() => _isPersonnelCardExpanded = !_isPersonnelCardExpanded),
                ),
              ],
            ),
          ),
          if (_isPersonnelCardExpanded) ...[
            const SizedBox(height: 12.0),
          const Text(
            'Admin defines authorized lab personnel across 4 operational levels: Manager, Supervisor, Technician, and Operator. Personnel log in with their credentials to access the laboratory workspace.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 16.0),

          // Role Distribution Chips
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: [
              _buildRoleStatChip('Manager', managerCount, const Color(0xFFEC4899), Icons.verified_user_rounded),
              _buildRoleStatChip('Supervisor', supervisorCount, const Color(0xFFF59E0B), Icons.supervisor_account_rounded),
              _buildRoleStatChip('Technician', technicianCount, const Color(0xFF38BDF8), Icons.build_circle_rounded),
              _buildRoleStatChip('Operator', operatorCount, const Color(0xFF10B981), Icons.person_rounded),
            ],
          ),
          const SizedBox(height: 20.0),

          // Role Selector Dropdown
          const Text('Assign User Level / Role:', style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFF2C415E),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedNewUserRole,
                isExpanded: true,
                dropdownColor: const Color(0xFF344D6E),
                style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedNewUserRole = val);
                },
                items: ['Manager', 'Supervisor', 'Technician', 'Operator'].map((role) {
                  final color = role == 'Manager'
                      ? const Color(0xFFEC4899)
                      : role == 'Supervisor'
                          ? const Color(0xFFF59E0B)
                          : role == 'Technician'
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF10B981);
                  final icon = role == 'Manager'
                      ? Icons.verified_user_rounded
                      : role == 'Supervisor'
                          ? Icons.supervisor_account_rounded
                          : role == 'Technician'
                              ? Icons.build_circle_rounded
                              : Icons.person_rounded;
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(icon, size: 16.0, color: color),
                        const SizedBox(width: 8.0),
                        Text(role, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // Full Name Input
          TextField(
            controller: _newOpFullNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13.0),
            decoration: InputDecoration(
              hintText: 'Full Name (e.g., Ahmed Al-Mansoori)',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF38BDF8), size: 16.0),
              filled: true,
              fillColor: const Color(0xFF2C415E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10.0),

          // Username Input
          TextField(
            controller: _newOpEmailController,
            style: const TextStyle(color: Colors.white, fontSize: 13.0),
            decoration: InputDecoration(
              hintText: 'Login Username (e.g. ahmed.m)',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8), size: 16.0),
              filled: true,
              fillColor: const Color(0xFF2C415E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
            ),
          ),
          const SizedBox(height: 10.0),

          // Password Input
          TextField(
            controller: _newOpPasswordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13.0),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 16.0),
              filled: true,
              fillColor: const Color(0xFF2C415E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16.0),

          SizedBox(
            width: double.infinity,
            height: 38.0,
            child: ElevatedButton.icon(
              onPressed: _registerNewOperator,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16.0),
              label: Text('Create $_selectedNewUserRole Account', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
            ),
          ),
          const SizedBox(height: 20.0),
          const Divider(color: Color(0xFF1E3A8A)),
          const SizedBox(height: 12.0),

          const Text(
            'Registered Laboratory Personnel:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8.0),
          Container(
            height: 160.0,
            decoration: BoxDecoration(
              color: const Color(0xFF2C415E),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: _operators.isEmpty
                ? const Center(
                    child: Text('No personnel registered yet.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    itemCount: _operators.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F293D), height: 8.0),
                    itemBuilder: (context, index) {
                      final op = _operators[index];
                      final opEmail = op['email'] ?? '';
                      final opName = op['name'] ?? opEmail;
                      final roleStr = op['role'] ?? 'operator';
                      final userRole = parseUserRole(roleStr);

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: userRole.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: userRole.color.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(userRole.icon, size: 11.0, color: userRole.color),
                                const SizedBox(width: 4.0),
                                Text(
                                  userRole.label.toUpperCase(),
                                  style: TextStyle(color: userRole.color, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opName,
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '@$opEmail',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF8E96A3), fontFamily: 'JetBrainsMono'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 16.0),
                            tooltip: 'Edit User',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _openEditOperatorDialog(op),
                          ),
                          const SizedBox(width: 8.0),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16.0),
                            tooltip: 'Delete User',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteOperator(opEmail, opName),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleStatChip(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.0, color: color),
          const SizedBox(width: 5.0),
          Text(
            '$count $label${count != 1 ? 's' : ''}',
            style: TextStyle(color: color, fontSize: 11.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePermissionsCard(double width) {
    final roles = [
      {'key': 'manager', 'label': 'Manager', 'color': const Color(0xFFEC4899), 'icon': Icons.verified_user_rounded},
      {'key': 'supervisor', 'label': 'Supervisor', 'color': const Color(0xFFF59E0B), 'icon': Icons.supervisor_account_rounded},
      {'key': 'technician', 'label': 'Technician', 'color': const Color(0xFF06B6D4), 'icon': Icons.build_circle_rounded},
      {'key': 'operator', 'label': 'Operator', 'color': const Color(0xFF10B981), 'icon': Icons.person_rounded},
    ];

    final permsConfig = [
      {
        'key': 'can_edit_records',
        'title': 'Edit Inspection Log Records',
        'subtitle': 'Allow users in this role to edit report data if mistakes or typos are found in submitted logs.',
      },
      {
        'key': 'can_delete_records',
        'title': 'Delete Inspection Entries',
        'subtitle': 'Allow removing specific ballistic test records from the database.',
      },
      {
        'key': 'can_export_reports',
        'title': 'Export Reports & Summaries',
        'subtitle': 'Allow generating and downloading formal PDF, Excel, and Word inspection reports.',
      },
      {
        'key': 'can_clear_logs',
        'title': 'Clear Daily Testing History',
        'subtitle': 'Allow wiping all test records from the Daily Test module.',
      },
      {
        'key': 'can_manage_rules',
        'title': 'Manage Testing Rules & Limits',
        'subtitle': 'Allow modifying ballistic pass/fail thresholds, limits, and caliber configurations.',
      },
    ];

    final rolePermsMap = Map<String, dynamic>.from(_adminRules['role_permissions'] ?? {});

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isPermissionsCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isPermissionsCardExpanded = !_isPermissionsCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF4D99DB)),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0284C7), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'Role Permissions & Access Matrix',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: Icon(_isPermissionsCardExpanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF0284C7)),
                  onPressed: () => setState(() => _isPermissionsCardExpanded = !_isPermissionsCardExpanded),
                ),
              ],
            ),
          ),
          if (_isPermissionsCardExpanded) ...[
            const SizedBox(height: 12.0),
          const Text(
            'Admin can grant permissions to specific roles (e.g., Supervisor can edit the data on the report if there is some mistake, delete records, or manage rules). Toggle permissions below; changes are saved and applied immediately.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 20.0),

          // Submission Alerts Switch (Admin & System-wide default)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF2C415E),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: _submissionAlertsEnabled ? const Color(0xFF0284C7) : const Color(0xFF1E3A8A),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _submissionAlertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                  color: _submissionAlertsEnabled ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                  size: 22.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Submission Alerts (All Users)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Display an instant popup alert notification for all users when a report is submitted. Can also be switched off at any time.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _submissionAlertsEnabled,
                  activeColor: const Color(0xFF0284C7),
                  onChanged: (val) async {
                    setState(() {
                      _submissionAlertsEnabled = val;
                      _adminRules['submission_alerts_enabled'] = val;
                    });
                    await _storageService.saveRules(_adminRules);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),

          // Roles List with Permissions
          ...roles.map((role) {
            final roleKey = role['key'] as String;
            final roleLabel = role['label'] as String;
            final roleColor = role['color'] as Color;
            final roleIcon = role['icon'] as IconData;
            final rolePerms = Map<String, dynamic>.from(rolePermsMap[roleKey] ?? {});

            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C415E),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: ExpansionTile(
                initiallyExpanded: roleKey == 'supervisor' || roleKey == 'manager',
                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                leading: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 18.0),
                ),
                title: Row(
                  children: [
                    Text(
                      roleLabel,
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 14.0),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        rolePerms['can_edit_records'] == true ? 'Can Edit Data' : 'Read-only Logs',
                        style: TextStyle(color: roleColor, fontSize: 10.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Manage permissions and capabilities for ${roleLabel.toLowerCase()}s',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
                children: permsConfig.map((p) {
                  final pKey = p['key'] as String;
                  final pTitle = p['title'] as String;
                  final pSubtitle = p['subtitle'] as String;
                  final bool isGranted = rolePerms[pKey] == true;

                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF1E3A8A))),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      activeColor: roleColor,
                      title: Text(
                        pTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        pSubtitle,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                      ),
                      value: isGranted,
                      onChanged: (newVal) async {
                        setState(() {
                          rolePerms[pKey] = newVal;
                          rolePermsMap[roleKey] = rolePerms;
                          _adminRules['role_permissions'] = rolePermsMap;
                        });
                        await _storageService.saveRules(_adminRules);
                      },
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildEquipmentFleetCard(double width) {
    final allRecords = [..._records, ..._dailyTestRecords];

    final weaponsList = List<Map<String, dynamic>>.from(
      (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return {'type': e.toString(), 'serial': ''};
      }),
    );
    final gp1List = List<String>.from(_adminRules['gp1_transducers'] as List<dynamic>? ?? []);
    final gp6List = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
    final epvatBarrels = List<String>.from(_adminRules['epvat_barrels'] as List<dynamic>? ?? []);
    final accBarrels = List<String>.from(_adminRules['accuracy_barrels'] as List<dynamic>? ?? []);
    final primerSuppliers = List<String>.from(_adminRules['primer_suppliers'] as List<dynamic>? ?? []);
    final propellantSuppliers = List<String>.from(_adminRules['propellant_suppliers'] as List<dynamic>? ?? []);
    final propellantCodes = List<String>.from(_adminRules['propellant_codes'] as List<dynamic>? ?? []);
    final propellantSupplierCodes = Map<String, dynamic>.from(_adminRules['propellant_supplier_codes'] as Map<dynamic, dynamic>? ?? {});

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isEquipmentCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isEquipmentCardExpanded = !_isEquipmentCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF4D99DB)),
                  ),
                  child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF0284C7), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'Equipment Fleet & Cumulative Round Tracking',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                Icon(
                  _isEquipmentCardExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFF0284C7),
                  size: 24.0,
                ),
              ],
            ),
          ),
          if (_isEquipmentCardExpanded) ...[
            const SizedBox(height: 12.0),
            const Text(
              'Admin enters Weapon Types & Serials, GP1/GP2 Transducers, EPVAT & Accuracy Barrels, and Component Suppliers. The system automatically tracks cumulative rounds fired through each asset.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 20.0),

            // 1. WEAPONS SECTION (Type & Serial)
            _buildAssetCategoryHeader('Weapons Registration (Type, Manufacturer & Serial)', Icons.military_tech_rounded, const Color(0xFF38BDF8)),
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF23364F),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weapon Category', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4.0),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C415E),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(color: const Color(0xFF1E3A8A)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _adminWeaponManufacturers.containsKey(_selectedAdminWeaponType) ? _selectedAdminWeaponType : 'Pistol',
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2C415E),
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedAdminWeaponType = val;
                                        final mfgList = _adminWeaponManufacturers[val] ?? ['Other'];
                                        _selectedAdminWeaponManufacturer = mfgList.first;
                                      });
                                    }
                                  },
                                  items: _adminWeaponManufacturers.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Manufacturer (Cascaded)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4.0),
                            Builder(builder: (ctx) {
                              final mfgList = _adminWeaponManufacturers[_selectedAdminWeaponType] ?? ['Other'];
                              final currentMfg = mfgList.contains(_selectedAdminWeaponManufacturer) ? _selectedAdminWeaponManufacturer : mfgList.first;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C415E),
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(color: const Color(0xFF1E3A8A)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: currentMfg,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2C415E),
                                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedAdminWeaponManufacturer = val;
                                        });
                                      }
                                    },
                                    items: mfgList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _newWeaponTypeInputCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Model / Variant (e.g., M9, M4A1, MP5)',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF2C415E),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _newWeaponSerialInputCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                          decoration: InputDecoration(
                            hintText: 'Serial No. (e.g., W-9012)',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF2C415E),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final model = _newWeaponTypeInputCtrl.text.trim();
                          final mfg = _selectedAdminWeaponManufacturer;
                          final weaponType = _selectedAdminWeaponType;
                          final cleanModel = model.isNotEmpty
                              ? (model.toLowerCase().startsWith(mfg.toLowerCase()) ? model : (mfg != 'Other' ? '$mfg $model' : model))
                              : (mfg != 'Other' ? '$mfg $weaponType' : weaponType);
                          final serial = _newWeaponSerialInputCtrl.text.trim();
                          if (cleanModel.isEmpty) return;
                          final list = List<Map<String, dynamic>>.from(
                            (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                              if (e is Map) return Map<String, dynamic>.from(e);
                              return {'type': e.toString(), 'serial': ''};
                            }),
                          );
                          list.add({
                            'type': cleanModel,
                            'serial': serial,
                            'category': weaponType,
                            'manufacturer': mfg,
                            'model': model.isNotEmpty ? model : cleanModel,
                          });
                          _adminRules['weapons'] = list;

                          // Also add to function_test weapons list if not present
                          final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                          final funcWeapons = List<String>.from(func['weapons'] ?? []);
                          final fullLabel = serial.isNotEmpty ? '$cleanModel (SN: $serial)' : cleanModel;
                          if (!funcWeapons.contains(fullLabel)) {
                            funcWeapons.add(fullLabel);
                            func['weapons'] = funcWeapons;
                            _adminRules['function_test'] = func;
                          }

                          // Also add to cyclic_rate weapons if not present
                          final cyclic = Map<String, dynamic>.from(_adminRules['cyclic_rate'] ?? {});
                          final cyclicWeapons = List<Map<String, dynamic>>.from(
                            (cyclic['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
                          );
                          if (!cyclicWeapons.any((w) => w['name'] == fullLabel)) {
                            cyclicWeapons.add({
                              'name': fullLabel,
                              'type': weaponType == 'Machine Gun' ? 'Linked' : 'Loose',
                              'min': 600,
                              'max': 950,
                            });
                            cyclic['weapons'] = cyclicWeapons;
                            _adminRules['cyclic_rate'] = cyclic;
                          }

                          await _storageService.saveRules(_adminRules);
                          setState(() {
                            _adminRules = Map<String, dynamic>.from(_adminRules);
                            _newWeaponTypeInputCtrl.clear();
                            _newWeaponSerialInputCtrl.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        ),
                        icon: const Icon(Icons.add, size: 16.0),
                        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: weaponsList.map((w) {
                final type = w['type'] ?? '';
                final serial = w['serial'] ?? '';
                final label = serial.isNotEmpty ? '$type (SN: $serial)' : '$type';
                final rounds = _storageService.calculateAssetRounds(allRecords, serial.isNotEmpty ? serial : type);
                return {
                  'label': label,
                  'serial': serial.isNotEmpty ? serial : type,
                  'rounds': rounds,
                  'category': 'Weapon',
                };
              }).toList(),
              accentColor: const Color(0xFF6366F1),
              onDelete: (item) async {
                weaponsList.removeWhere((w) {
                  final serial = w['serial'] ?? '';
                  final type = w['type'] ?? '';
                  final key = serial.isNotEmpty ? serial : type;
                  return key == item['serial'];
                });
                _adminRules['weapons'] = weaponsList;

                final fullLabel = item['label'] as String? ?? '';
                final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                final funcWeapons = List<String>.from(func['weapons'] ?? []);
                funcWeapons.remove(fullLabel);
                func['weapons'] = funcWeapons;
                _adminRules['function_test'] = func;

                final cyclic = Map<String, dynamic>.from(_adminRules['cyclic_rate'] ?? {});
                final cyclicWeapons = List<Map<String, dynamic>>.from(
                  (cyclic['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
                );
                cyclicWeapons.removeWhere((w) => w['name'] == fullLabel);
                cyclic['weapons'] = cyclicWeapons;
                _adminRules['cyclic_rate'] = cyclic;

                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
            const SizedBox(height: 18.0),

            // 2. GP6 TRANSDUCER SERIAL NUMBERS (EPVAT CHAMBER & PORT)
            _buildAssetCategoryHeader('GP6 Transducer Serial Numbers (Unified Chamber & Port Sensors)', Icons.sensors_rounded, const Color(0xFF06B6D4)),
            const SizedBox(height: 4.0),
            const Text(
              'Register all GP6 piezoelectric transducers here in one field. In the test entry module, operators will select which sensor is mounted as GP6 (1) Chamber and GP6 (2) Port.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newGP1TransducerCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'GP6 Transducer S.N. (e.g., GP6-001, PCB 119B SN#4120)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final serial = _newGP1TransducerCtrl.text.trim();
                    if (serial.isEmpty) return;
                    
                    final gp6Transducers = List<String>.from(_adminRules['gp6_transducers'] as List<dynamic>? ?? []);
                    if (!gp6Transducers.contains(serial)) {
                      gp6Transducers.add(serial);
                      _adminRules['gp6_transducers'] = gp6Transducers;
                    }
                    final list = List<String>.from(_adminRules['gp1_transducers'] as List<dynamic>? ?? []);
                    if (!list.contains(serial)) {
                      list.add(serial);
                      _adminRules['gp1_transducers'] = list;
                    }
                    final list2 = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
                    if (!list2.contains(serial)) {
                      list2.add(serial);
                      _adminRules['gp6_serials'] = list2;
                    }
                    final gpMap = Map<String, dynamic>.from(_adminRules['gp_transducers'] as Map<dynamic, dynamic>? ?? {});
                    final gp1Internal = List<String>.from(gpMap['gp1'] as List<dynamic>? ?? []);
                    if (!gp1Internal.contains(serial)) {
                      gp1Internal.add(serial);
                      gpMap['gp1'] = gp1Internal;
                    }
                    final gp2Internal = List<String>.from(gpMap['gp2'] as List<dynamic>? ?? []);
                    if (!gp2Internal.contains(serial)) {
                      gp2Internal.add(serial);
                      gpMap['gp2'] = gp2Internal;
                    }
                    _adminRules['gp_transducers'] = gpMap;

                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newGP1TransducerCtrl.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  ),
                  child: const Text('Add Sensor', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Builder(builder: (context) {
              final Set<String> allSensors = {};
              for (final k in ['gp6_transducers', 'gp1_transducers', 'gp6_serials']) {
                final l = _adminRules[k];
                if (l is List) {
                  for (final item in l) {
                    final s = item.toString().trim();
                    if (s.isNotEmpty) allSensors.add(s);
                  }
                }
              }
              final gpMap = _adminRules['gp_transducers'];
              if (gpMap is Map) {
                for (final sub in ['gp1', 'gp2']) {
                  final l = gpMap[sub];
                  if (l is List) {
                    for (final item in l) {
                      final s = item.toString().trim();
                      if (s.isNotEmpty) allSensors.add(s);
                    }
                  }
                }
              }
              final sensorList = allSensors.toList();

              return _buildAssetItemList(
                items: sensorList.map((sn) {
                  final rounds = _storageService.calculateAssetRounds(allRecords, sn);
                  return {
                    'label': sn,
                    'serial': sn,
                    'rounds': rounds,
                    'category': 'GP6 Transducer',
                  };
                }).toList(),
                accentColor: const Color(0xFF06B6D4),
                onDelete: (item) async {
                  final sn = item['serial'] as String;
                  
                  final gp6Transducers = List<String>.from(_adminRules['gp6_transducers'] as List<dynamic>? ?? []);
                  gp6Transducers.remove(sn);
                  _adminRules['gp6_transducers'] = gp6Transducers;

                  final gp1List = List<String>.from(_adminRules['gp1_transducers'] as List<dynamic>? ?? []);
                  gp1List.remove(sn);
                  _adminRules['gp1_transducers'] = gp1List;

                  final gp6List = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
                  gp6List.remove(sn);
                  _adminRules['gp6_serials'] = gp6List;

                  final gpMap = Map<String, dynamic>.from(_adminRules['gp_transducers'] as Map<dynamic, dynamic>? ?? {});
                  final gp1Internal = List<String>.from(gpMap['gp1'] as List<dynamic>? ?? []);
                  gp1Internal.remove(sn);
                  gpMap['gp1'] = gp1Internal;
                  final gp2Internal = List<String>.from(gpMap['gp2'] as List<dynamic>? ?? []);
                  gp2Internal.remove(sn);
                  gpMap['gp2'] = gp2Internal;
                  _adminRules['gp_transducers'] = gpMap;

                  await _storageService.saveRules(_adminRules);
                  setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
                },
              );
            }),
            const SizedBox(height: 18.0),

            // 4. EPVAT BARREL TEST SERIALS
            _buildAssetCategoryHeader('EPVAT Barrel Test Serial Numbers (Separately per Caliber)', Icons.adjust_rounded, const Color(0xFF06B6D4)),
            const SizedBox(height: 8.0),
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF23364F),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Text('Select Caliber:', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: EntryTab.calibers.contains(_selectedEpvatBarrelCaliber) ? _selectedEpvatBarrelCaliber : EntryTab.calibers.first,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C415E),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF06B6D4)),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedEpvatBarrelCaliber = val);
                        },
                        items: EntryTab.calibers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newEpvatBarrelCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'EPVAT Barrel Serial (e.g., EPV-556-01)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final serial = _newEpvatBarrelCtrl.text.trim();
                    if (serial.isEmpty) return;
                    final byCal = Map<String, dynamic>.from(_adminRules['epvat_barrels_by_caliber'] as Map? ?? {});
                    final list = List<String>.from(byCal[_selectedEpvatBarrelCaliber] as List? ?? []);
                    if (!list.contains(serial)) {
                      list.add(serial);
                      byCal[_selectedEpvatBarrelCaliber] = list;
                      _adminRules['epvat_barrels_by_caliber'] = byCal;
                    }
                    final allEpv = List<String>.from(_adminRules['epvat_barrels'] as List? ?? []);
                    if (!allEpv.contains(serial)) {
                      allEpv.add(serial);
                      _adminRules['epvat_barrels'] = allEpv;
                    }
                    final bList = List<String>.from(_adminRules['barrel_serial_numbers'] as List? ?? []);
                    if (!bList.contains(serial)) {
                      bList.add(serial);
                      _adminRules['barrel_serial_numbers'] = bList;
                    }
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newEpvatBarrelCtrl.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: (() {
                final byCal = Map<String, dynamic>.from(_adminRules['epvat_barrels_by_caliber'] as Map? ?? {});
                final calBarrels = List<String>.from(byCal[_selectedEpvatBarrelCaliber] as List? ?? epvatBarrels);
                return calBarrels.map((sn) {
                  final rounds = _storageService.calculateAssetRounds(allRecords, sn);
                  return {
                    'label': '$sn  ($_selectedEpvatBarrelCaliber)',
                    'serial': sn,
                    'rounds': rounds,
                    'category': 'EPVAT Barrel',
                  };
                }).toList();
              })(),
              accentColor: const Color(0xFF06B6D4),
              onDelete: (item) async {
                final sn = item['serial'] as String;
                final byCal = Map<String, dynamic>.from(_adminRules['epvat_barrels_by_caliber'] as Map? ?? {});
                final list = List<String>.from(byCal[_selectedEpvatBarrelCaliber] as List? ?? []);
                list.remove(sn);
                byCal[_selectedEpvatBarrelCaliber] = list;
                _adminRules['epvat_barrels_by_caliber'] = byCal;

                bool usedElsewhere = false;
                for (final v in byCal.values) {
                  if (v is List && v.contains(sn)) {
                    usedElsewhere = true;
                    break;
                  }
                }
                if (!usedElsewhere) {
                  epvatBarrels.remove(sn);
                  _adminRules['epvat_barrels'] = epvatBarrels;
                  final bList = List<String>.from(_adminRules['barrel_serial_numbers'] as List? ?? []);
                  bList.remove(sn);
                  _adminRules['barrel_serial_numbers'] = bList;
                }
                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
            const SizedBox(height: 18.0),

            // 5. ACCURACY BARREL TEST SERIALS
            _buildAssetCategoryHeader('Accuracy Barrel Test Serial Numbers (Separately per Caliber)', Icons.radar_rounded, const Color(0xFFF59E0B)),
            const SizedBox(height: 8.0),
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: const Color(0xFF23364F),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Text('Select Caliber:', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12.0, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: EntryTab.calibers.contains(_selectedAccuracyBarrelCaliber) ? _selectedAccuracyBarrelCaliber : EntryTab.calibers.first,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C415E),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF59E0B)),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAccuracyBarrelCaliber = val);
                        },
                        items: EntryTab.calibers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newAccuracyBarrelCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'Accuracy Barrel Serial (e.g., ACC-B-101)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final serial = _newAccuracyBarrelCtrl.text.trim();
                    if (serial.isEmpty) return;
                    final byCal = Map<String, dynamic>.from(_adminRules['accuracy_barrels_by_caliber'] as Map? ?? {});
                    final list = List<String>.from(byCal[_selectedAccuracyBarrelCaliber] as List? ?? []);
                    if (!list.contains(serial)) {
                      list.add(serial);
                      byCal[_selectedAccuracyBarrelCaliber] = list;
                      _adminRules['accuracy_barrels_by_caliber'] = byCal;
                    }
                    final allAcc = List<String>.from(_adminRules['accuracy_barrels'] as List? ?? []);
                    if (!allAcc.contains(serial)) {
                      allAcc.add(serial);
                      _adminRules['accuracy_barrels'] = allAcc;
                    }
                    final bList = List<String>.from(_adminRules['barrel_serial_numbers'] as List? ?? []);
                    if (!bList.contains(serial)) {
                      bList.add(serial);
                      _adminRules['barrel_serial_numbers'] = bList;
                    }
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newAccuracyBarrelCtrl.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: (() {
                final byCal = Map<String, dynamic>.from(_adminRules['accuracy_barrels_by_caliber'] as Map? ?? {});
                final calBarrels = List<String>.from(byCal[_selectedAccuracyBarrelCaliber] as List? ?? accBarrels);
                return calBarrels.map((sn) {
                  final rounds = _storageService.calculateAssetRounds(allRecords, sn);
                  return {
                    'label': '$sn  ($_selectedAccuracyBarrelCaliber)',
                    'serial': sn,
                    'rounds': rounds,
                    'category': 'Accuracy Barrel',
                  };
                }).toList();
              })(),
              accentColor: const Color(0xFFF59E0B),
              onDelete: (item) async {
                final sn = item['serial'] as String;
                final byCal = Map<String, dynamic>.from(_adminRules['accuracy_barrels_by_caliber'] as Map? ?? {});
                final list = List<String>.from(byCal[_selectedAccuracyBarrelCaliber] as List? ?? []);
                list.remove(sn);
                byCal[_selectedAccuracyBarrelCaliber] = list;
                _adminRules['accuracy_barrels_by_caliber'] = byCal;

                bool usedElsewhere = false;
                for (final v in byCal.values) {
                  if (v is List && v.contains(sn)) {
                    usedElsewhere = true;
                    break;
                  }
                }
                if (!usedElsewhere) {
                  accBarrels.remove(sn);
                  _adminRules['accuracy_barrels'] = accBarrels;
                  final bList = List<String>.from(_adminRules['barrel_serial_numbers'] as List? ?? []);
                  bList.remove(sn);
                  _adminRules['barrel_serial_numbers'] = bList;
                }
                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
            const SizedBox(height: 18.0),

            // 6. PRIMER SUPPLIERS
            _buildAssetCategoryHeader('Primer Suppliers (Component & Lot Acceptance Tests)', Icons.grain_rounded, const Color(0xFFEC4899)),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPrimerSupplierCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Supplier Name (e.g., CBC, UNIS "GINIX", S&B, MD)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFEC4899))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final sup = _newPrimerSupplierCtrl.text.trim();
                    if (sup.isEmpty) return;
                    final list = List<String>.from(_adminRules['primer_suppliers'] as List<dynamic>? ?? []);
                    if (!list.contains(sup)) {
                      list.add(sup);
                      _adminRules['primer_suppliers'] = list;
                      await _storageService.saveRules(_adminRules);
                      setState(() {
                        _adminRules = Map<String, dynamic>.from(_adminRules);
                        _newPrimerSupplierCtrl.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: primerSuppliers.map((s) => {'label': s, 'serial': s, 'rounds': 0, 'category': 'Primer Supplier'}).toList(),
              accentColor: const Color(0xFFEC4899),
              onDelete: (item) async {
                primerSuppliers.remove(item['serial']);
                _adminRules['primer_suppliers'] = primerSuppliers;
                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
            const SizedBox(height: 18.0),

            // 7. PROPELLANT SUPPLIERS
            _buildAssetCategoryHeader('Propellant Suppliers (Component Test)', Icons.local_fire_department_rounded, const Color(0xFFF97316)),
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPropellantSupplierCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Propellant Supplier (e.g., Explosia, Gold Force, PB Clermont, Milan)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFF97316))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final sup = _newPropellantSupplierCtrl.text.trim();
                    if (sup.isEmpty) return;
                    final list = List<String>.from(_adminRules['propellant_suppliers'] as List<dynamic>? ?? []);
                    if (!list.contains(sup)) {
                      list.add(sup);
                      _adminRules['propellant_suppliers'] = list;
                      await _storageService.saveRules(_adminRules);
                      setState(() {
                        _adminRules = Map<String, dynamic>.from(_adminRules);
                        _newPropellantSupplierCtrl.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: propellantSuppliers.map((s) => {'label': s, 'serial': s, 'rounds': 0, 'category': 'Propellant Supplier'}).toList(),
              accentColor: const Color(0xFFF97316),
              onDelete: (item) async {
                final sup = item['serial'] as String;
                propellantSuppliers.remove(sup);
                _adminRules['propellant_suppliers'] = propellantSuppliers;
                final supCodesMap = Map<String, dynamic>.from(_adminRules['propellant_supplier_codes'] as Map<dynamic, dynamic>? ?? {});
                supCodesMap.remove(sup);
                _adminRules['propellant_supplier_codes'] = supCodesMap;
                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
            const SizedBox(height: 18.0),

            // 8. PROPELLANT CODES LINKED WITH SUPPLIER
            _buildAssetCategoryHeader('Propellant Codes linked with Supplier (Component & EPVAT)', Icons.qr_code_rounded, const Color(0xFFA855F7)),
            const SizedBox(height: 8.0),
            Row(
              children: [
                if (propellantSuppliers.isNotEmpty) ...[
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C415E),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFF1E3A8A)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: propellantSuppliers.contains(_selectedPropellantCodeSupplier)
                              ? _selectedPropellantCodeSupplier
                              : propellantSuppliers.first,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C415E),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFA855F7)),
                          style: const TextStyle(color: Colors.white, fontSize: 12.0),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPropellantCodeSupplier = val);
                            }
                          },
                          items: propellantSuppliers.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _newPropellantCodeCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Propellant Code (e.g., D-073.4, S-060, P-30, PB-540)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF2C415E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFFA855F7))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () async {
                    final code = _newPropellantCodeCtrl.text.trim();
                    if (code.isEmpty) return;
                    final list = List<String>.from(_adminRules['propellant_codes'] as List<dynamic>? ?? []);
                    if (!list.contains(code)) {
                      list.add(code);
                      _adminRules['propellant_codes'] = list;
                    }
                    final currentSup = propellantSuppliers.contains(_selectedPropellantCodeSupplier)
                        ? _selectedPropellantCodeSupplier
                        : (propellantSuppliers.isNotEmpty ? propellantSuppliers.first : '');
                    if (currentSup.isNotEmpty) {
                      final supCodesMap = Map<String, dynamic>.from(_adminRules['propellant_supplier_codes'] as Map<dynamic, dynamic>? ?? {});
                      final codesForSup = List<String>.from(supCodesMap[currentSup] as List<dynamic>? ?? []);
                      if (!codesForSup.contains(code)) {
                        codesForSup.add(code);
                        supCodesMap[currentSup] = codesForSup;
                        _adminRules['propellant_supplier_codes'] = supCodesMap;
                      }
                    }
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newPropellantCodeCtrl.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA855F7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildAssetItemList(
              items: propellantCodes.map((c) {
                String supLabel = '';
                for (final entry in propellantSupplierCodes.entries) {
                  final cList = List<String>.from(entry.value as List<dynamic>? ?? []);
                  if (cList.contains(c)) {
                    supLabel = entry.key;
                    break;
                  }
                }
                final display = supLabel.isNotEmpty ? '$c  ($supLabel)' : c;
                return {'label': display, 'serial': c, 'rounds': 0, 'category': 'Propellant Code'};
              }).toList(),
              accentColor: const Color(0xFFA855F7),
              onDelete: (item) async {
                final code = item['serial'] as String;
                propellantCodes.remove(code);
                _adminRules['propellant_codes'] = propellantCodes;
                final supCodesMap = Map<String, dynamic>.from(_adminRules['propellant_supplier_codes'] as Map<dynamic, dynamic>? ?? {});
                for (final k in supCodesMap.keys) {
                  final list = List<String>.from(supCodesMap[k] as List<dynamic>? ?? []);
                  if (list.remove(code)) {
                    supCodesMap[k] = list;
                  }
                }
                _adminRules['propellant_supplier_codes'] = supCodesMap;
                await _storageService.saveRules(_adminRules);
                setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetCategoryHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15.0, color: color),
        const SizedBox(width: 6.0),
        Text(
          title,
          style: TextStyle(color: color, fontSize: 12.0, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAssetItemList({
    required List<Map<String, dynamic>> items,
    required Color accentColor,
    required void Function(Map<String, dynamic>) onDelete,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2C415E),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: const Color(0xFF1E3A8A)),
        ),
        child: const Text(
          'No assets registered in this category.',
          style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 120.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C415E),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E3A8A), height: 6.0),
        itemBuilder: (context, index) {
          final item = items[index];
          final label = item['label'] as String;
          final rounds = item['rounds'] as int;

          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grain_rounded, size: 10.0, color: accentColor),
                    const SizedBox(width: 4.0),
                    Text(
                      '$rounds rounds',
                      style: TextStyle(color: accentColor, fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 15.0),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onDelete(item),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5)),
          Text(val, style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12.5, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showEditFormulaDialog({
    required BuildContext context,
    required int index,
    required Map<String, dynamic> item,
    required String caliber,
    required Future<void> Function(Map<String, dynamic>) onSave,
  }) {
    final nameCtrl = TextEditingController(text: item['name'] ?? '');
    final exprCtrl = TextEditingController(text: item['formula'] ?? '');
    final limitCtrl = TextEditingController(text: '${item['limit'] ?? ''}');
    final unitCtrl = TextEditingController(text: '${item['unit'] ?? ''}');
    String selectedOp = item['operator'] ?? '<=';
    if (!['<=', '>=', '<', '>', '==', '±'].contains(selectedOp)) {
      selectedOp = '<=';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: const BorderSide(color: Color(0xFF06B6D4), width: 1.2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF06B6D4), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Formula for $caliber',
                      style: const TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rule / Check Name', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        decoration: _getFormulaFieldDecoration(hint: 'Rule name'),
                      ),
                      const SizedBox(height: 12),
                      const Text('Formula Expression', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: exprCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono'),
                        decoration: _getFormulaFieldDecoration(hint: 'Expression'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Quick Tokens:', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.0)),
                          ...['P1_MEAN', 'P1_SD', 'P1_MAX_INDIVIDUAL', 'P2_MEAN', 'P2_SD', 'VEL_MEAN', 'VEL_SD'].map((token) => InkWell(
                            onTap: () {
                              final current = exprCtrl.text;
                              if (current.isEmpty) {
                                exprCtrl.text = token;
                              } else {
                                exprCtrl.text = '$current $token';
                              }
                              exprCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: exprCtrl.text.length),
                              );
                              setDialogState(() {});
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Text(token, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.0, fontFamily: 'JetBrainsMono')),
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Operator', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C415E),
                                    borderRadius: BorderRadius.circular(6.0),
                                    border: Border.all(color: const Color(0xFF1E3A8A)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedOp,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF344D6E),
                                      style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedOp = val);
                                        }
                                      },
                                      items: ['<=', '>=', '<', '>', '==', '±'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Limit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: limitCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                                  decoration: _getFormulaFieldDecoration(hint: '4200'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Unit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: unitCtrl,
                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                                  decoration: _getFormulaFieldDecoration(hint: 'bar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final expr = exprCtrl.text.trim();
                    final limit = limitCtrl.text.trim();
                    final unit = unitCtrl.text.trim();
                    if (name.isEmpty || expr.isEmpty) return;
                    Navigator.pop(ctx);
                    await onSave({
                      'name': name,
                      'formula': expr,
                      'operator': selectedOp,
                      'limit': limit.isEmpty ? '0' : limit,
                      'unit': unit.isEmpty ? (expr.toLowerCase().contains('vel') ? 'm/s' : 'bar') : unit,
                      'description': item['description'] ?? 'Custom rule for $caliber',
                    });
                  },
                  icon: const Icon(Icons.check, size: 16, color: Colors.white),
                  label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRulesManagementCard(double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isRulesCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isRulesCardExpanded = !_isRulesCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF6366F1)),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: Color(0xFF6366F1), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                const Expanded(
                  child: Text(
                    'Evaluation Rules & Requirements',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                Icon(
                  _isRulesCardExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFF6366F1),
                  size: 24.0,
                ),
              ],
            ),
          ),
          if (_isRulesCardExpanded) ...[
            const SizedBox(height: 12.0),
            const Text(
              'Configure specifications and instructions. These rules auto-sentence operator entries.',
              style: TextStyle(fontSize: 12.0, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            
            // Test selector Dropdown
            const Text('Select Test to Configure', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C415E),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: DropdownButton<String>(
                value: _selectedRuleTest,
                isExpanded: true,
                dropdownColor: const Color(0xFF344D6E),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRuleTest = val;
                    });
                    _syncRulesControllers();
                  }
                },
                items: [
                  'Waterproof Test',
                  'Residual Stress Test',
                  'Extraction Force Test',
                  'Accuracy Test',
                  'EPVAT Test',
                  'Primer Sensitivity Test',
                  'Function Test',
                  'Firing Rate Cycle Test',
                  'GP6 Transducers (EPVAT)',
                  'Barrels',
                  'Weapons',
                ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              ),
            ),
            const SizedBox(height: 12.0),

          // Caliber selector for tests that have caliber-specific specifications
          Builder(builder: (context) {
            final bool isCaliberAware = _selectedRuleTest != 'Firing Rate Cycle Test' &&
                _selectedRuleTest != 'Barrel Serial Numbers' &&
                _selectedRuleTest != 'Barrels' &&
                _selectedRuleTest != 'GP6 Transducers (EPVAT)' &&
                _selectedRuleTest != 'GP Transducers (GP1 & GP2)' &&
                _selectedRuleTest != 'Weapons';
            if (!isCaliberAware) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF06B6D4), size: 16),
                      const SizedBox(width: 8.0),
                      const Text(
                        'Caliber for Specification Rules',
                        style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Caliber-Specific Rules',
                          style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  const Text(
                    'Select a caliber below to configure its independent requirements, tolerances, and instructions.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                  ),
                  const SizedBox(height: 10.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C415E),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _ruleSelectedCaliber,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF344D6E),
                        style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _ruleSelectedCaliber = val;
                              _ruleSelectedFuncCaliber = val;
                              _ruleSelectedEpvatCaliberForMass = val;
                            });
                            _syncRulesControllers();
                          }
                        },
                        items: [
                          '5.56x45 SS109',
                          '5.56x45 M193',
                          '5.56x45 .223 69 grains',
                          '5.56x45 .223 55 grains',
                          '5.56x45 .223 77 grains',
                          '5.56x45 M200 Blank',
                          '7.62x51 M80',
                          '7.62x51 .308',
                          '7.62x51 M82 Blank',
                          '9x19mm Para',
                          '9x19mm Luger',
                          '9x19mm Match',
                          '9x19mm 124 grains CMJ',
                        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: Color(0xFF1E3A8A)),
          const SizedBox(height: 12.0),

          // Render fields based on selected test
          if (_selectedRuleTest == 'Waterproof Test') ...[
            _buildRuleTextField('Retest Limit for $_ruleSelectedCaliber (Total Leaks >=)', _ruleWaterproofRetestCtrl),
            _buildRuleTextField('Reject Limit for $_ruleSelectedCaliber (Total Leaks >=)', _ruleWaterproofRejectCtrl),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _ruleWaterproofInstructionsCtrl, isMultiline: true),
            const SizedBox(height: 8.0),
            const Text('Fallback Blank Caliber Defaults (if not configured per caliber):', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6.0),
            Row(
              children: [
                Expanded(child: _buildRuleTextField('Blank Retest Limit (Total Leaks >=)', _ruleWaterproofBlankRetestCtrl)),
                const SizedBox(width: 8.0),
                Expanded(child: _buildRuleTextField('Blank Reject Limit (Total Leaks >=)', _ruleWaterproofBlankRejectCtrl)),
              ],
            ),
          ] else if (_selectedRuleTest == 'Residual Stress Test') ...[
            _buildRuleTextField('Retest Limit for $_ruleSelectedCaliber (Total Splits/Cracks >=)', _ruleStressRetestCtrl),
            _buildRuleTextField('Reject Limit for $_ruleSelectedCaliber (Total Splits/Cracks >=)', _ruleStressRejectCtrl),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _ruleStressInstructionsCtrl, isMultiline: true),
            _buildClassificationImageSection('residual_stress', 'Residual Stress Classification Reference Picture for $_ruleSelectedCaliber'),
          ] else if (_selectedRuleTest == 'Extraction Force Test') ...[
            _buildRuleTextField('Minimum Extraction Force for $_ruleSelectedCaliber (N)', _ruleExtMinForceCtrl),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _ruleExtInstructionsCtrl, isMultiline: true),
          ] else if (_selectedRuleTest == 'Accuracy Test') ...[
            _buildRuleTextField('Max Mean Radius for $_ruleSelectedCaliber (mm)', _ruleAccMaxMeanRadiusCtrl),
            _buildRuleTextField('Max SD for $_ruleSelectedCaliber (mm)', _ruleAccMaxSDCtrl),
            _buildRuleTextField('Condition SD for $_ruleSelectedCaliber (mm)', _ruleAccCondSDCtrl),
            _buildRuleTextField('Min Target Velocity for $_ruleSelectedCaliber (m/s)', _ruleAccMinVelCtrl),
            _buildRuleTextField('Max Target Velocity for $_ruleSelectedCaliber (m/s)', _ruleAccMaxVelCtrl),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _ruleAccInstructionsCtrl, isMultiline: true),
          ] else if (_selectedRuleTest == 'EPVAT Test') ...[
            // --- Bullet Mass for Kinetic Energy ---
            const Text(
              'PROJECTILE MASS & KINETIC ENERGY',
              style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 1.0),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Set projectile mass per caliber to auto-calculate kinetic energy E = ½mv² at +21 °C.',
              style: TextStyle(fontSize: 11.0, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 10.0),
            _buildRuleTextField('Bullet Mass (grams) for $_ruleSelectedCaliber', _ruleEpvBulletMassCtrl),
            const SizedBox(height: 12.0),
            _buildRuleTextField(
              'Admin Instruction / Recommendation for $_ruleSelectedCaliber (Advisory only — does not decide quality status)',
              _ruleEpvInstructionsCtrl,
              isMultiline: true,
            ),
            const SizedBox(height: 20.0),
            const Text('Custom Caliber Sentencing Calculations', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            const Text(
              'Define custom formulas to evaluate sentencing checks for this caliber. The operator logs round data and the system calculates these formulas. If any check fails, the entry is sentenced as Rejected.',
              style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                const Text('Select Caliber: ', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C415E),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _ruleSelectedCaliber,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF344D6E),
                        style: const TextStyle(color: Colors.white, fontSize: 13.0),
                        onChanged: (val) {
                          setState(() {
                            _ruleSelectedCaliber = val!;
                          });
                        },
                        items: EntryTab.calibers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Builder(builder: (context) {
              final formulasMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
              final list = List<dynamic>.from(formulasMap[_ruleSelectedCaliber] ?? []);
              
              Future<void> saveFormulas(Map<String, dynamic> newMap, {String? feedback}) async {
                if (_ruleSelectedCaliber == '5.56x45 SS109' || _ruleSelectedCaliber == 'SS109') {
                  final curVal = newMap[_ruleSelectedCaliber];
                  newMap['5.56x45 SS109'] = curVal;
                  newMap['SS109'] = curVal;
                }
                _adminRules['epvat']?['custom_formulas'] = newMap;
                await _storageService.saveRules(_adminRules);
                if (context.mounted) {
                  setState(() {
                    _adminRules = Map<String, dynamic>.from(_adminRules);
                  });
                  if (feedback != null && feedback.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(feedback)),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets toolbar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                          newMap[_ruleSelectedCaliber] = EpvatFormulaHelper.getDefaultFormulas();
                          await saveFormulas(newMap, feedback: 'Standard EPVAT preset formulas registered and saved for $_ruleSelectedCaliber.');
                        },
                        icon: const Icon(Icons.playlist_add_check, size: 15),
                        label: const Text('Load Standard Presets', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_task, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('P1 Mean + 3SD (+21°C)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          _ruleNewFormulaNameCtrl.text = 'P1 3-Sigma (+21°C)';
                          _ruleNewFormulaExprCtrl.text = 'P1_MEAN + 3 * P1_SD';
                          _ruleNewFormulaOperator = '<=';
                          _ruleNewFormulaLimitCtrl.text = '4200';
                          _ruleNewFormulaUnitCtrl.text = 'bar';
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preset loaded into registration form below. Click "Register & Save" to confirm.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_task, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('P1 Delta (|21°C - 52°C|)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          _ruleNewFormulaNameCtrl.text = 'P1 Difference (+21°C vs +52°C)';
                          _ruleNewFormulaExprCtrl.text = 'abs(P1_MEAN_21 - P1_MEAN_52)';
                          _ruleNewFormulaOperator = '<=';
                          _ruleNewFormulaLimitCtrl.text = '450';
                          _ruleNewFormulaUnitCtrl.text = 'bar';
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preset loaded into registration form below. Click "Register & Save" to confirm.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_task, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Velocity Delta (|21°C - 52°C|)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          _ruleNewFormulaNameCtrl.text = 'Velocity Delta (+21°C vs +52°C)';
                          _ruleNewFormulaExprCtrl.text = 'abs(VEL_MEAN_21 - VEL_MEAN_52)';
                          _ruleNewFormulaOperator = '<=';
                          _ruleNewFormulaLimitCtrl.text = '30';
                          _ruleNewFormulaUnitCtrl.text = 'm/s';
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preset loaded into registration form below. Click "Register & Save" to confirm.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_task, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Velocity Tolerance (±30 m/s)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          _ruleNewFormulaNameCtrl.text = 'Velocity Tolerance (+21°C vs +52°C)';
                          _ruleNewFormulaExprCtrl.text = 'abs(VEL_MEAN_21 - VEL_MEAN_52)';
                          _ruleNewFormulaOperator = '±';
                          _ruleNewFormulaLimitCtrl.text = '30';
                          _ruleNewFormulaUnitCtrl.text = 'm/s';
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preset loaded into registration form below. Click "Register & Save" to confirm.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Dedicated Register / Edit Formula Box with persistent controllers
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF23364F),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: _editingFormulaIndex == null ? const Color(0xFF06B6D4).withOpacity(0.4) : const Color(0xFFF59E0B),
                        width: _editingFormulaIndex == null ? 1.0 : 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _editingFormulaIndex == null ? Icons.add_circle_outline : Icons.edit_note_rounded,
                              color: _editingFormulaIndex == null ? const Color(0xFF06B6D4) : const Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _editingFormulaIndex == null
                                  ? 'Register New Formula for $_ruleSelectedCaliber'
                                  : 'Edit Formula #$_editingFormulaIndex for $_ruleSelectedCaliber',
                              style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                            ),
                            if (_editingFormulaIndex != null) ...[
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _editingFormulaIndex = null;
                                    _ruleNewFormulaNameCtrl.clear();
                                    _ruleNewFormulaExprCtrl.clear();
                                    _ruleNewFormulaLimitCtrl.clear();
                                    _ruleNewFormulaUnitCtrl.text = 'bar';
                                    _ruleNewFormulaOperator = '<=';
                                  });
                                },
                                icon: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                label: const Text('Cancel Edit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Formula Name
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Rule / Check Name', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _ruleNewFormulaNameCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                    decoration: _getFormulaFieldDecoration(hint: 'e.g., P1 3-Sigma Upper Bound'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Formula Expression
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Formula Expression', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _ruleNewFormulaExprCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                                    decoration: _getFormulaFieldDecoration(hint: 'e.g., P1_MEAN + 3 * P1_SD'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Operator
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Operator', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C415E),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(color: const Color(0xFF1E3A8A)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _ruleNewFormulaOperator,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF344D6E),
                                        style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _ruleNewFormulaOperator = val);
                                          }
                                        },
                                        items: ['<=', '>=', '<', '>', '==', '±'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Limit
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Limit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _ruleNewFormulaLimitCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                                    decoration: _getFormulaFieldDecoration(hint: '4200'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Unit
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Unit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _ruleNewFormulaUnitCtrl,
                                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                                    decoration: _getFormulaFieldDecoration(hint: 'bar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick variable tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Quick Tokens:', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5)),
                            ...['P1_MEAN', 'P1_SD', 'P1_MAX_INDIVIDUAL', 'P2_MEAN', 'P2_SD', 'VEL_MEAN', 'VEL_SD'].map((token) => InkWell(
                              onTap: () {
                                final current = _ruleNewFormulaExprCtrl.text;
                                if (current.isEmpty) {
                                  _ruleNewFormulaExprCtrl.text = token;
                                } else {
                                  _ruleNewFormulaExprCtrl.text = '$current $token';
                                }
                                _ruleNewFormulaExprCtrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _ruleNewFormulaExprCtrl.text.length),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Text(token, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontFamily: 'JetBrainsMono')),
                              ),
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_editingFormulaIndex != null) ...[
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _editingFormulaIndex = null;
                                    _ruleNewFormulaNameCtrl.clear();
                                    _ruleNewFormulaExprCtrl.clear();
                                    _ruleNewFormulaLimitCtrl.clear();
                                    _ruleNewFormulaUnitCtrl.text = 'bar';
                                    _ruleNewFormulaOperator = '<=';
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF94A3B8),
                                  side: const BorderSide(color: Color(0xFF475569)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton.icon(
                              onPressed: () async {
                                final name = _ruleNewFormulaNameCtrl.text.trim();
                                final expr = _ruleNewFormulaExprCtrl.text.trim();
                                final limit = _ruleNewFormulaLimitCtrl.text.trim();
                                final unit = _ruleNewFormulaUnitCtrl.text.trim();
                                
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a Rule / Check Name.'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                if (expr.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a Formula Expression.'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                
                                final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                final formulaData = {
                                  'name': name,
                                  'formula': expr,
                                  'operator': _ruleNewFormulaOperator,
                                  'limit': limit.isEmpty ? '0' : limit,
                                  'unit': unit.isEmpty ? (expr.toLowerCase().contains('vel') ? 'm/s' : 'bar') : unit,
                                  'description': 'Custom rule for $_ruleSelectedCaliber',
                                };

                                if (_editingFormulaIndex != null && _editingFormulaIndex! < curList.length) {
                                  curList[_editingFormulaIndex!] = formulaData;
                                  newMap[_ruleSelectedCaliber] = curList;
                                  await saveFormulas(newMap, feedback: 'Formula "$name" updated and saved successfully for $_ruleSelectedCaliber.');
                                  setState(() {
                                    _editingFormulaIndex = null;
                                  });
                                } else {
                                  curList.add(formulaData);
                                  newMap[_ruleSelectedCaliber] = curList;
                                  await saveFormulas(newMap, feedback: 'Formula "$name" registered and saved successfully for $_ruleSelectedCaliber.');
                                }
                                
                                _ruleNewFormulaNameCtrl.clear();
                                _ruleNewFormulaExprCtrl.clear();
                                _ruleNewFormulaLimitCtrl.clear();
                              },
                              icon: Icon(_editingFormulaIndex == null ? Icons.check_circle_outline : Icons.save_outlined, size: 16),
                              label: Text(
                                _editingFormulaIndex == null
                                    ? 'Register & Save Formula for $_ruleSelectedCaliber'
                                    : 'Update Formula for $_ruleSelectedCaliber',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _editingFormulaIndex == null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18.0),

                  // Header for existing registered formulas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registered Formulas for $_ruleSelectedCaliber (${list.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  if (list.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Center(
                        child: Text(
                          'No custom formulas registered yet for $_ruleSelectedCaliber. Use the form above or click "Load Standard Presets".',
                          style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Rule / Check Name', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text('Formula Expression', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Operator', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Limit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Unit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        SizedBox(width: 58),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E3A8A), height: 14),
                    ...List.generate(list.length, (i) {
                      final item = Map<String, dynamic>.from(list[i] as Map);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item['formula'] ?? '',
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C415E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['operator'] ?? '<=',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item['limit'] ?? ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item['unit'] ?? ''}',
                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit formula',
                                onPressed: () {
                                  _showEditFormulaDialog(
                                    context: context,
                                    index: i,
                                    item: item,
                                    caliber: _ruleSelectedCaliber,
                                    onSave: (updated) async {
                                      final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                      final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                      if (i < curList.length) {
                                        curList[i] = updated;
                                        newMap[_ruleSelectedCaliber] = curList;
                                        await saveFormulas(newMap, feedback: 'Formula "${updated['name']}" updated and saved.');
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete formula',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                                      ),
                                      title: const Text('Delete Formula Rule?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                      content: Text(
                                        'Are you sure you want to delete the formula "${item['name']}" for $_ruleSelectedCaliber?',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                    final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                    final removed = newList.removeAt(i);
                                    newMap[_ruleSelectedCaliber] = newList;
                                    final removedName = (removed is Map ? removed['name'] : '') ?? '';
                                    await saveFormulas(newMap, feedback: 'Formula "$removedName" deleted and saved.');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF344D6E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: const BorderSide(color: Color(0xFF1E3A8A)),
                              ),
                              title: const Text('EPVAT Adjustable Formulas & Variables Guide', style: TextStyle(color: Colors.white, fontSize: 16.0)),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('You can write intuitive formulas using natural names or variable tokens with math operators (+, -, *, /, abs):', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0)),
                                    const SizedBox(height: 14.0),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C415E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF1E3A8A)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text('Common Real-World Examples:', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12.0)),
                                          SizedBox(height: 6),
                                          Text('• 3-Sigma Pressure (+21°C): P1 Mean @ 21 + 3 * P1 SD @ 21', style: TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'JetBrainsMono')),
                                          Text('  Calculation: 3500 + 3 * 100 = 3800 bar', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.0)),
                                          SizedBox(height: 6),
                                          Text('• Temp Pressure Delta (21°C vs 52°C): abs(P1 Mean @ 21 - P1 Mean @ 52)', style: TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'JetBrainsMono')),
                                          Text('  Calculation: |3500 - 3950| = 450 bar', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.0)),
                                          SizedBox(height: 6),
                                          Text('• Velocity Delta (21°C vs 52°C): abs(Vel Mean @ 21 - Vel Mean @ 52)', style: TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'JetBrainsMono')),
                                          Text('  Calculation: |920 - 935| = 15 m/s', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.0)),
                                          SizedBox(height: 6),
                                          Text('• Port Pressure 3-Sigma: P2 Mean @ 21 + 3 * P2 SD @ 21', style: TextStyle(color: Colors.white, fontSize: 11.5, fontFamily: 'JetBrainsMono')),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),
                                    _buildVarGuideRow('Chamber P1:', 'P1 Mean @ 21, P1 SD @ 21, P1 Max @ 21, P1 Min @ 21\\nP1 Mean @ 52, P1 SD @ 52, P1 Max @ 52, P1 Min @ 52\\nP1 Mean @ 54, P1 SD @ 54, P1 Max @ 54, P1 Min @ 54'),
                                    const SizedBox(height: 10.0),
                                    _buildVarGuideRow('Port P2:', 'P2 Mean @ 21, P2 SD @ 21, P2 Max @ 21, P2 Min @ 21\\nP2 Mean @ 52, P2 SD @ 52, P2 Max @ 52, P2 Min @ 52\\nP2 Mean @ 54, P2 SD @ 54, P2 Max @ 54, P2 Min @ 54'),
                                    const SizedBox(height: 10.0),
                                    _buildVarGuideRow('Velocity V:', 'Vel Mean @ 21, Vel SD @ 21, Vel Max @ 21, Vel Min @ 21\\nVel Mean @ 52, Vel SD @ 52, Vel Max @ 52, Vel Min @ 52\\nVel Mean @ 54, Vel SD @ 54, Vel Max @ 54, Vel Min @ 54'),
                                    const SizedBox(height: 10.0),
                                    const Text('Tip: Formulas can also use shorthand tokens (p1_mean_21, vel_mean_52) or natural words (P1 Mean, 3SD).', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF06B6D4))))
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.help_outline, size: 14),
                        label: const Text('Formulas & Variables Guide', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12.0)),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ] else if (_selectedRuleTest == 'Primer Sensitivity Test') ...[
            _buildRuleTextField('Drop Weight (grams) for $_ruleSelectedCaliber', _rulePrimerDropWeightCtrl),
            _buildRuleTextField('Min All-Fire Height (H_max limit, mm) for $_ruleSelectedCaliber', _rulePrimerMinAllFireCtrl),
            _buildRuleTextField('Max No-Fire Height (H_min limit, mm) for $_ruleSelectedCaliber', _rulePrimerMaxNoFireCtrl),
            Row(
              children: [
                Expanded(child: _buildRuleTextField('Mean Height H̄ Min (mm)', _rulePrimerHbarMinCtrl)),
                const SizedBox(width: 8.0),
                Expanded(child: _buildRuleTextField('Mean Height H̄ Max (mm)', _rulePrimerHbarMaxCtrl)),
              ],
            ),
            _buildRuleTextField('Max Standard Deviation S (mm) for $_ruleSelectedCaliber', _rulePrimerMaxSDCtrl),
            Row(
              children: [
                Expanded(child: _buildRuleTextField('Retest Misfires Limit (>=)', _rulePrimerRetestMisfiresCtrl)),
                const SizedBox(width: 8.0),
                Expanded(child: _buildRuleTextField('Reject Misfires Limit (>=)', _rulePrimerRejectMisfiresCtrl)),
              ],
            ),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _rulePrimerInstructionsCtrl, isMultiline: true),
          ] else if (_selectedRuleTest == 'Firing Rate Cycle Test') ...[
            const Text(
              'Configure weapon types and cyclic rate limits. The operator selects a weapon category (Rifle or Machine Gun) and weapon model, then inputs the measured cyclic rate which must fall within the configured range (empty max limit means no upper limit).',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            Builder(builder: (context) {
              final weapons = List<Map<String, dynamic>>.from(
                (_adminRules['cyclic_rate']?['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map))
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Weapon Name', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Category', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Min RPM', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Max RPM', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                      SizedBox(width: 32),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E3A8A), height: 14),
                  ...List.generate(weapons.length, (i) {
                    final w = weapons[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _buildCyclicRuleMiniField(weapons, i, 'name', isNumber: false)),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C415E),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: const Color(0xFF1E3A8A)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: (w['type'] == 'Machine Gun') ? 'Machine Gun' : 'Rifle',
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF344D6E),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                  onChanged: (val) async {
                                    setState(() {
                                      final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                                      final map = Map<String, dynamic>.from(list[i] as Map);
                                      map['type'] = val;
                                      list[i] = map;
                                      _adminRules['cyclic_rate'] = {'weapons': list};
                                    });
                                    await _storageService.saveRules(_adminRules);
                                  },
                                  items: ['Rifle', 'Machine Gun'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(flex: 2, child: _buildCyclicRuleMiniField(weapons, i, 'min')),
                          const SizedBox(width: 6),
                          Expanded(flex: 2, child: _buildCyclicRuleMiniField(weapons, i, 'max')),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              setState(() {
                                final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                                list.removeAt(i);
                                _adminRules['cyclic_rate'] = {'weapons': list};
                              });
                              await _storageService.saveRules(_adminRules);
                            },
                            child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        setState(() {
                          final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                          list.add({'name': 'New Weapon', 'type': 'Rifle', 'min': 550, 'max': 920});
                          _adminRules['cyclic_rate'] = {'weapons': list};
                        });
                        await _storageService.saveRules(_adminRules);
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Weapon', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF06B6D4),
                        side: const BorderSide(color: Color(0xFF06B6D4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ] else if (_selectedRuleTest == 'GP6 Transducers (EPVAT)' || _selectedRuleTest == 'GP Transducers (GP1 & GP2)' || _selectedRuleTest == 'GP6 Transducers') ...[
            const Text(
              'Manage authorized GP6 Transducers for EPVAT ballistic testing. All piezoelectric sensors registered here form a single unified inventory. In the test entry module, operators will select which sensor is mounted as GP6 (1) Chamber and which is GP6 (2) Gas Port.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleNewGPTransducerCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'Enter GP6 Transducer S.N. (e.g., GP6-001, PCB 119B SN#4120)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.0),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: () async {
                    final text = _ruleNewGPTransducerCtrl.text.trim();
                    if (text.isNotEmpty) {
                      final gp6Transducers = List<String>.from(_adminRules['gp6_transducers'] as List<dynamic>? ?? []);
                      if (!gp6Transducers.contains(text)) {
                        gp6Transducers.add(text);
                        _adminRules['gp6_transducers'] = gp6Transducers;
                      }

                      final gp1List = List<String>.from(_adminRules['gp1_transducers'] as List<dynamic>? ?? []);
                      if (!gp1List.contains(text)) {
                        gp1List.add(text);
                        _adminRules['gp1_transducers'] = gp1List;
                      }

                      final gp6List = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
                      if (!gp6List.contains(text)) {
                        gp6List.add(text);
                        _adminRules['gp6_serials'] = gp6List;
                      }

                      final gpMap = Map<String, dynamic>.from(_adminRules['gp_transducers'] as Map<dynamic, dynamic>? ?? {});
                      final gp1Internal = List<String>.from(gpMap['gp1'] as List<dynamic>? ?? []);
                      if (!gp1Internal.contains(text)) {
                        gp1Internal.add(text);
                        gpMap['gp1'] = gp1Internal;
                      }
                      final gp2Internal = List<String>.from(gpMap['gp2'] as List<dynamic>? ?? []);
                      if (!gp2Internal.contains(text)) {
                        gp2Internal.add(text);
                        gpMap['gp2'] = gp2Internal;
                      }
                      _adminRules['gp_transducers'] = gpMap;

                      await _storageService.saveRules(_adminRules);
                      setState(() {
                        _adminRules = Map<String, dynamic>.from(_adminRules);
                        _ruleNewGPTransducerCtrl.clear();
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('GP6 Sensor "$text" registered and saved successfully.'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add GP6 Sensor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Single unified list of registered GP6 transducers
            Builder(builder: (context) {
              final Set<String> allSensors = {};
              for (final k in ['gp6_transducers', 'gp1_transducers', 'gp6_serials']) {
                final l = _adminRules[k];
                if (l is List) {
                  for (final item in l) {
                    final s = item.toString().trim();
                    if (s.isNotEmpty) allSensors.add(s);
                  }
                }
              }
              final gpMap = _adminRules['gp_transducers'];
              if (gpMap is Map) {
                for (final sub in ['gp1', 'gp2']) {
                  final l = gpMap[sub];
                  if (l is List) {
                    for (final item in l) {
                      final s = item.toString().trim();
                      if (s.isNotEmpty) allSensors.add(s);
                    }
                  }
                }
              }
              final sensorList = allSensors.toList();

              if (sensorList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No GP6 transducers registered.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic)),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sensorList.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F293D), height: 1),
                  itemBuilder: (context, idx) {
                    final name = sensorList[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono')),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            tooltip: 'Delete sensor',
                            onPressed: () async {
                              final gp6Transducers = List<String>.from(_adminRules['gp6_transducers'] as List<dynamic>? ?? []);
                              gp6Transducers.remove(name);
                              _adminRules['gp6_transducers'] = gp6Transducers;

                              final gp1List = List<String>.from(_adminRules['gp1_transducers'] as List<dynamic>? ?? []);
                              gp1List.remove(name);
                              _adminRules['gp1_transducers'] = gp1List;

                              final gp6List = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
                              gp6List.remove(name);
                              _adminRules['gp6_serials'] = gp6List;

                              final updatedGp = Map<String, dynamic>.from(_adminRules['gp_transducers'] as Map<dynamic, dynamic>? ?? {});
                              final updated1 = List<String>.from(updatedGp['gp1'] ?? []);
                              updated1.remove(name);
                              updatedGp['gp1'] = updated1;
                              final updated2 = List<String>.from(updatedGp['gp2'] ?? []);
                              updated2.remove(name);
                              updatedGp['gp2'] = updated2;
                              _adminRules['gp_transducers'] = updatedGp;

                              await _storageService.saveRules(_adminRules);
                              setState(() {
                                _adminRules = Map<String, dynamic>.from(_adminRules);
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sensor "$name" deleted and saved.'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ] else if (_selectedRuleTest == 'Barrels' || _selectedRuleTest == 'Barrel Serial Numbers') ...[
            const Text(
              'Manage authorized Barrel Serial Numbers. Operators will pick from this list in Accuracy, EPVAT, and Terminal Effect tests.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleNewBarrelSNCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: 'Enter Barrel S.N. (e.g., B-1050)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.0),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: () async {
                    final sn = _ruleNewBarrelSNCtrl.text.trim();
                    if (sn.isNotEmpty) {
                      final list = List<String>.from(_adminRules['barrel_serial_numbers'] ?? []);
                      if (!list.contains(sn)) {
                        list.add(sn);
                        _adminRules['barrel_serial_numbers'] = list;
                      }
                      final epvatB = List<String>.from(_adminRules['epvat_barrels'] as List<dynamic>? ?? []);
                      if (!epvatB.contains(sn)) {
                        epvatB.add(sn);
                        _adminRules['epvat_barrels'] = epvatB;
                      }
                      final accB = List<String>.from(_adminRules['accuracy_barrels'] as List<dynamic>? ?? []);
                      if (!accB.contains(sn)) {
                        accB.add(sn);
                        _adminRules['accuracy_barrels'] = accB;
                      }
                      await _storageService.saveRules(_adminRules);
                      setState(() {
                        _adminRules = Map<String, dynamic>.from(_adminRules);
                        _ruleNewBarrelSNCtrl.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Barrel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Text('Registered Barrel S.N. List:', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            Builder(builder: (context) {
              final list = List<String>.from(_adminRules['barrel_serial_numbers'] ?? []);
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No barrel serial numbers registered yet.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic)),
                );
              }
              return Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F293D), height: 1),
                  itemBuilder: (context, idx) {
                    final sn = list[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, color: Color(0xFF06B6D4), size: 16),
                              const SizedBox(width: 8),
                              Text(sn, style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final updated = List<String>.from(_adminRules['barrel_serial_numbers'] ?? []);
                              final removedSn = updated.removeAt(idx);
                              _adminRules['barrel_serial_numbers'] = updated;
                              final epvatB = List<String>.from(_adminRules['epvat_barrels'] as List<dynamic>? ?? []);
                              epvatB.remove(removedSn);
                              _adminRules['epvat_barrels'] = epvatB;
                              final accB = List<String>.from(_adminRules['accuracy_barrels'] as List<dynamic>? ?? []);
                              accB.remove(removedSn);
                              _adminRules['accuracy_barrels'] = accB;
                              await _storageService.saveRules(_adminRules);
                              setState(() {
                                _adminRules = Map<String, dynamic>.from(_adminRules);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ] else if (_selectedRuleTest == 'Weapons') ...[
            const Text(
              'Manage authorized Weapons for Function Tests and Firing Rate Cycle Tests. Operators will select from these registered firearms during test executions.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ruleNewWeaponNameCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13.0),
                          decoration: InputDecoration(
                            hintText: 'Weapon Model (e.g., M4A1 Carbine, MP5, FN MINIMI)',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.0),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C415E),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _ruleNewWeaponType,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF344D6E),
                            style: const TextStyle(color: Colors.white, fontSize: 12.0),
                            onChanged: (v) => setState(() => _ruleNewWeaponType = v ?? 'Loose'),
                            items: const [
                              DropdownMenuItem(value: 'Loose', child: Text('Loose')),
                              DropdownMenuItem(value: 'Linked', child: Text('Linked')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _ruleNewWeaponMinRpmCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Min RPM',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11.5),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _ruleNewWeaponMaxRpmCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Max RPM',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11.5),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final wpName = _ruleNewWeaponNameCtrl.text.trim();
                          if (wpName.isNotEmpty) {
                            // 1. Add to function_test weapons list
                            final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                            final funcList = List<String>.from(func['weapons'] ?? []);
                            if (!funcList.contains(wpName)) {
                              funcList.add(wpName);
                              func['weapons'] = funcList;
                              _adminRules['function_test'] = func;
                            }
                            
                            // 2. Add to cyclic_rate weapons list
                            final cyclic = Map<String, dynamic>.from(_adminRules['cyclic_rate'] ?? {});
                            final cyclicWeapons = List<Map<String, dynamic>>.from(
                              (cyclic['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
                            );
                            final minRpm = int.tryParse(_ruleNewWeaponMinRpmCtrl.text.trim()) ?? 600;
                            final maxRpm = int.tryParse(_ruleNewWeaponMaxRpmCtrl.text.trim());
                            if (!cyclicWeapons.any((w) => w['name'] == wpName)) {
                              cyclicWeapons.add({
                                'name': wpName,
                                'type': _ruleNewWeaponType,
                                'min': minRpm,
                                'max': maxRpm,
                              });
                              cyclic['weapons'] = cyclicWeapons;
                              _adminRules['cyclic_rate'] = cyclic;
                            }

                            // 3. Add to fleet weapons
                            final fleetWeapons = List<Map<String, dynamic>>.from(
                              (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                                if (e is Map) return Map<String, dynamic>.from(e);
                                return {'type': e.toString(), 'serial': ''};
                              }),
                            );
                            if (!fleetWeapons.any((w) => (w['type'] ?? '') == wpName)) {
                              fleetWeapons.add({'type': wpName, 'serial': '', 'category': _ruleNewWeaponType, 'manufacturer': 'Generic'});
                              _adminRules['weapons'] = fleetWeapons;
                            }

                            await _storageService.saveRules(_adminRules);
                            setState(() {
                              _adminRules = Map<String, dynamic>.from(_adminRules);
                              _ruleNewWeaponNameCtrl.clear();
                              _ruleNewWeaponMinRpmCtrl.clear();
                              _ruleNewWeaponMaxRpmCtrl.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Weapon'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            const Text('Registered Weapons List:', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            Builder(builder: (context) {
              final cyclic = _adminRules['cyclic_rate'] ?? {};
              final cyclicWeapons = List<Map<String, dynamic>>.from(
                (cyclic['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
              );
              final func = _adminRules['function_test'] ?? {};
              final funcWeapons = List<String>.from(func['weapons'] ?? []);
              
              // Combined unique weapon names
              final Set<String> allNames = {...funcWeapons, ...cyclicWeapons.map((w) => w['name']?.toString() ?? '').where((n) => n.isNotEmpty)};
              
              if (allNames.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No weapons registered yet.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic)),
                );
              }
              return Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allNames.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F293D), height: 1),
                  itemBuilder: (context, idx) {
                    final wpName = allNames.elementAt(idx);
                    final cyclicMatch = cyclicWeapons.firstWhere((w) => w['name'] == wpName, orElse: () => {});
                    final feedType = cyclicMatch['type'] ?? 'Standard';
                    final minR = cyclicMatch['min'];
                    final maxR = cyclicMatch['max'];
                    final rpmInfo = minR != null ? ' | Cyclic: $minR${maxR != null ? ' - $maxR' : '+'} RPM' : '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_outlined, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 8),
                              Text(wpName, style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text('$feedType$rpmInfo', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final updatedFunc = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                              final updatedFuncList = List<String>.from(updatedFunc['weapons'] ?? []);
                              updatedFuncList.remove(wpName);
                              updatedFunc['weapons'] = updatedFuncList;

                              final updatedCyclic = Map<String, dynamic>.from(_adminRules['cyclic_rate'] ?? {});
                              final updatedCyclicList = List<Map<String, dynamic>>.from(
                                (updatedCyclic['weapons'] as List<dynamic>? ?? []).map((w) => Map<String, dynamic>.from(w as Map)),
                              );
                              updatedCyclicList.removeWhere((w) => w['name'] == wpName);
                              updatedCyclic['weapons'] = updatedCyclicList;

                              final fleetWeapons = List<Map<String, dynamic>>.from(
                                (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                                  if (e is Map) return Map<String, dynamic>.from(e);
                                  return {'type': e.toString(), 'serial': ''};
                                }),
                              );
                              fleetWeapons.removeWhere((w) => (w['type'] ?? '') == wpName || '${w['type']} (SN: ${w['serial']})' == wpName);
                              _adminRules['weapons'] = fleetWeapons;

                              _adminRules['function_test'] = updatedFunc;
                              _adminRules['cyclic_rate'] = updatedCyclic;
                              await _storageService.saveRules(_adminRules);
                              setState(() {
                                _adminRules = Map<String, dynamic>.from(_adminRules);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ] else if (_selectedRuleTest == 'Function Test') ...[
            const Text(
              'Configure max allowed defect thresholds and specify what defect types belong to each of the 4 severity levels per caliber. Also manage authorized weapons and defect classification pictures.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),

            const Text('Caliber Specification (Defect Limits & Types)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C415E),
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: DropdownButton<String>(
                value: _ruleSelectedFuncCaliber,
                isExpanded: true,
                dropdownColor: const Color(0xFF344D6E),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 13.0),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _saveCurrentFunctionCaliberRules();
                      _ruleSelectedFuncCaliber = val;
                      _loadFunctionCaliberRules(val);
                    });
                  }
                },
                items: [
                  '5.56x45 SS109',
                  '5.56x45 M193',
                  '5.56x45 M200 Blank',
                  '7.62x51 M80',
                  '7.62x51 M82',
                  '7.62x51 M62 Tracer',
                  '9x19mm Parabellum',
                  '12.7x99 NATO',
                  'default',
                ].map((c) => DropdownMenuItem(value: c, child: Text(c == 'default' ? 'Default Limits (Fallback)' : c))).toList(),
              ),
            ),
            const SizedBox(height: 16.0),

            Builder(builder: (context) {
              final func = _adminRules['function_test'] ?? {};
              final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
              final calRule = Map<String, dynamic>.from(calibersMap[_ruleSelectedFuncCaliber] ?? {});
              final bool isCategories = calRule['schema_type'] == 'categories';

              if (isCategories) {
                final cats = Map<String, dynamic>.from(calRule['categories'] ?? {});
                final catKeys = cats.keys.toList();
                return Column(
                  children: catKeys.map((catKey) {
                    final retestCtrl = _ruleFuncCatRetestCtrls.putIfAbsent(catKey, () => TextEditingController(text: (cats[catKey]?['retest_limit'] ?? 0).toString()));
                    final rejectCtrl = _ruleFuncCatRejectCtrls.putIfAbsent(catKey, () => TextEditingController(text: (cats[catKey]?['reject_limit'] ?? 1).toString()));
                    final descCtrl = _ruleFuncCatDescCtrls.putIfAbsent(catKey, () => TextEditingController(text: (cats[catKey]?['description'] ?? '').toString()));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildFunctionCategoryConfigCard(
                        categoryName: catKey,
                        retestLimitCtrl: retestCtrl,
                        rejectLimitCtrl: rejectCtrl,
                        descCtrl: descCtrl,
                      ),
                    );
                  }).toList(),
                );
              }

              return Column(
                children: [
                  _buildFunctionLevelConfigCard(
                    title: 'Level 1: Critical Defect',
                    badgeColor: const Color(0xFFEF4444),
                    maxLimitCtrl: _ruleFuncL1MaxCtrl,
                    retestLimitCtrl: _ruleFuncL1RetestCtrl,
                    rejectLimitCtrl: _ruleFuncL1RejectCtrl,
                    descCtrl: _ruleFuncL1DescCtrl,
                    ruleNote: 'Exceeding reject limit results in REJECTED status. Exceeding retest limit results in RETEST.',
                  ),
                  const SizedBox(height: 12.0),
                  _buildFunctionLevelConfigCard(
                    title: 'Level 2: Major Defect',
                    badgeColor: const Color(0xFFF97316),
                    maxLimitCtrl: _ruleFuncL2MaxCtrl,
                    retestLimitCtrl: _ruleFuncL2RetestCtrl,
                    rejectLimitCtrl: _ruleFuncL2RejectCtrl,
                    descCtrl: _ruleFuncL2DescCtrl,
                    ruleNote: 'Exceeding reject limit results in REJECTED status. Exceeding retest limit results in RETEST.',
                  ),
                  const SizedBox(height: 12.0),
                  _buildFunctionLevelConfigCard(
                    title: 'Level 3: Minor Defect',
                    badgeColor: const Color(0xFFFBBF24),
                    maxLimitCtrl: _ruleFuncL3MaxCtrl,
                    retestLimitCtrl: _ruleFuncL3RetestCtrl,
                    rejectLimitCtrl: _ruleFuncL3RejectCtrl,
                    descCtrl: _ruleFuncL3DescCtrl,
                    ruleNote: 'Exceeding retest limit triggers RETEST status.',
                  ),
                  const SizedBox(height: 12.0),
                  _buildFunctionLevelConfigCard(
                    title: 'Level 4: Cosmetic / Minor Defect',
                    badgeColor: const Color(0xFF38BDF8),
                    maxLimitCtrl: _ruleFuncL4MaxCtrl,
                    retestLimitCtrl: _ruleFuncL4RetestCtrl,
                    rejectLimitCtrl: _ruleFuncL4RejectCtrl,
                    descCtrl: _ruleFuncL4DescCtrl,
                    ruleNote: 'Exceeding retest limit triggers RETEST status.',
                  ),
                ],
              );
            }),
            const SizedBox(height: 18.0),
            const Divider(color: Color(0xFF1F293D)),
            const SizedBox(height: 14.0),

            const Text(
              'REGISTERED WEAPONS FOR FUNCTION TEST',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 0.5),
            ),
            const SizedBox(height: 6.0),
            const Text(
              'Operators will select one of these registered firearms when performing Function Tests.',
              style: TextStyle(fontSize: 11.0, color: Color(0xFF8E96A3)),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleNewFuncWeaponCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0),
                    decoration: InputDecoration(
                      hintText: 'Enter Weapon Model (e.g., M4A1, G3A3, MP5)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.0),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: () async {
                    final wpName = _ruleNewFuncWeaponCtrl.text.trim();
                    if (wpName.isNotEmpty) {
                      final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                      final list = List<String>.from(func['weapons'] ?? []);
                      if (!list.contains(wpName)) {
                        list.add(wpName);
                        func['weapons'] = list;
                        _adminRules['function_test'] = func;

                        final fleetWeapons = List<Map<String, dynamic>>.from(
                          (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                            if (e is Map) return Map<String, dynamic>.from(e);
                            return {'type': e.toString(), 'serial': ''};
                          }),
                        );
                        if (!fleetWeapons.any((w) => (w['type'] ?? '') == wpName)) {
                          fleetWeapons.add({'type': wpName, 'serial': '', 'category': 'Rifle', 'manufacturer': 'Generic'});
                          _adminRules['weapons'] = fleetWeapons;
                        }
                        await _storageService.saveRules(_adminRules);
                        setState(() {
                          _adminRules = Map<String, dynamic>.from(_adminRules);
                          _ruleNewFuncWeaponCtrl.clear();
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Weapon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            const Text('Registered Weapons List:', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            Builder(builder: (context) {
              final func = _adminRules['function_test'] ?? {};
              final list = List<String>.from(func['weapons'] ?? []);
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No weapons registered yet.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic)),
                );
              }
              return Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1F293D), height: 1),
                  itemBuilder: (context, idx) {
                    final wp = list[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_outlined, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 8),
                              Text(wp, style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                              final updated = List<String>.from(func['weapons'] ?? []);
                              final wp = updated.removeAt(idx);
                              func['weapons'] = updated;
                              _adminRules['function_test'] = func;

                              final fleetWeapons = List<Map<String, dynamic>>.from(
                                (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                                  if (e is Map) return Map<String, dynamic>.from(e);
                                  return {'type': e.toString(), 'serial': ''};
                                }),
                              );
                              fleetWeapons.removeWhere((w) => (w['type'] ?? '') == wp);
                              _adminRules['weapons'] = fleetWeapons;

                              await _storageService.saveRules(_adminRules);
                              setState(() {
                                _adminRules = Map<String, dynamic>.from(_adminRules);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
            _buildClassificationImageSection('function_test', 'Function Test Defect Classification Reference Picture'),
          ],
          
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            height: 38.0,
            child: ElevatedButton.icon(
              onPressed: _handleSaveRules,
              icon: const Icon(Icons.save_outlined, size: 16.0),
              label: const Text('Save Rules & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunctionLevelConfigCard({
    required String title,
    required Color badgeColor,
    required TextEditingController maxLimitCtrl,
    required TextEditingController retestLimitCtrl,
    required TextEditingController rejectLimitCtrl,
    required TextEditingController descCtrl,
    required String ruleNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: badgeColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: badgeColor.withOpacity(0.35)),
                ),
                child: Text(
                  title,
                  style: TextStyle(color: badgeColor, fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  ruleNote,
                  style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Retest Limit', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: retestLimitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFFFBBF24))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reject Limit', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: rejectLimitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFFEF4444))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Defect Types / Descriptions Included', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12.0),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Comma-separated defect types...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFF6366F1))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCategoryConfigCard({
    required String categoryName,
    required TextEditingController retestLimitCtrl,
    required TextEditingController rejectLimitCtrl,
    required TextEditingController descCtrl,
  }) {
    Color catColor = const Color(0xFF0284C7);
    if (categoryName.contains('Misfire') || categoryName.contains('bore') || categoryName.contains('Hangfire')) {
      catColor = const Color(0xFFEF4444);
    } else if (categoryName.contains('Primer') || categoryName.contains('Case') || categoryName.contains('casualties')) {
      catColor = const Color(0xFFF97316);
    } else if (categoryName.contains('Stoppage') || categoryName.contains('extract')) {
      catColor = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: catColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: catColor.withOpacity(0.35)),
                ),
                child: Text(
                  categoryName,
                  style: TextStyle(color: catColor, fontSize: 12.0, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10.0),
              const Expanded(
                child: Text(
                  'Configured limits and sub-defect items for this category.',
                  style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Retest Limit', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: retestLimitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFFFBBF24))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reject Limit', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: rejectLimitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFFEF4444))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Included Sub-Defects (Comma-separated)', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12.0),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter defects (e.g. Misfire, Split case)...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6.0)), borderSide: BorderSide(color: Color(0xFF6366F1))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTextField(String label, TextEditingController controller, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4.0),
          TextField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyclicRuleMiniField(List<Map<String, dynamic>> weapons, int index, String key, {bool isNumber = true}) {
    final value = weapons[index][key];
    final String initial = value == null ? '' : value.toString();
    return TextFormField(
      initialValue: initial,
      key: ValueKey('cyclic_${index}_$key'),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
      ),
      onChanged: (val) {
        final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
        final weaponMap = Map<String, dynamic>.from(list[index] as Map);
        if (isNumber) {
          if (val.trim().isEmpty) {
            weaponMap[key] = null;
          } else {
            final parsed = int.tryParse(val.trim());
            if (parsed != null) {
              weaponMap[key] = parsed;
            }
          }
        } else {
          weaponMap[key] = val;
        }
        list[index] = weaponMap;
        _adminRules['cyclic_rate'] = {'weapons': list};
        _storageService.saveRules(_adminRules);
      },
    );
  }

  InputDecoration _getFormulaFieldDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11.5),
      fillColor: Colors.black.withOpacity(0.2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4.0), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
    );
  }

  Widget _buildVarGuideRow(String title, String vars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2.0),
        Text(vars, style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontFamily: 'JetBrainsMono')),
      ],
    );
  }

  Widget _buildCertificateTemplateCard(double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: _isCertTemplateCardExpanded ? 20.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isCertTemplateCardExpanded = !_isCertTemplateCardExpanded),
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFF16A34A)),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 20.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Final Lot Acceptance Certificate Templates',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        'Customize sample sizes, requirements, and authorized signatories per caliber',
                        style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Per-Caliber',
                    style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  _isCertTemplateCardExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFF16A34A),
                  size: 24.0,
                ),
              ],
            ),
          ),
          if (_isCertTemplateCardExpanded) ...[
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 18.0),
                  SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      'The specifications and sample sizes configured below are dynamically injected into the exported Final Lot Acceptance Certificate for this caliber. Use line breaks in requirement boxes to format multi-line conditions.',
                      style: TextStyle(fontSize: 12.0, color: Color(0xFF166534), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // Caliber Selection Dropdown
            const Text('Select Caliber to Configure Template', style: TextStyle(color: Color(0xFF475569), fontSize: 12.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C415E),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xFF1E3A8A)),
              ),
              child: DropdownButton<String>(
                value: _certSelectedCaliber,
                isExpanded: true,
                dropdownColor: const Color(0xFF344D6E),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _certSelectedCaliber = val;
                      _loadCertTemplateForCaliber(val);
                    });
                  }
                },
                items: EntryTab.calibers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              ),
            ),
            const SizedBox(height: 16.0),

            // Signatories Section
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.draw_outlined, size: 18.0, color: Color(0xFF0284C7)),
                      SizedBox(width: 8.0),
                      Text('Certificate Signatories (3-Column Signature Block)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCertInputField(
                          label: 'Approved By (Column 2 Title / Name)',
                          controller: _certSupervisorNameCtrl,
                          hintText: 'Action Ballistic & Engineering Supervisor',
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: _buildCertInputField(
                          label: 'Authorized By (Column 3 Title / Name)',
                          controller: _certManagerNameCtrl,
                          hintText: 'Acting QC & Engineering Manager',
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '* Note: Column 1 ("Prepared By / Ballistic Technician") automatically resolves to the technician who logged the test entries.',
                    style: TextStyle(fontSize: 11.0, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            const Text(
              '7 Standard Acceptance Tests Specification Setup',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10.0),

            // 1. Waterproof Test
            _buildCertTestSection(
              testNumber: '1',
              testTitle: 'Waterproof Test',
              icon: Icons.water_drop_outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certWpSampleCtrl,
                      hintText: '20 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements',
                      controller: _certWpReqCtrl,
                      hintText: 'No. of Leaks ≤ 6 Leaks',
                    ),
                  ),
                ],
              ),
            ),

            // 2. Extraction Force Test
            _buildCertTestSection(
              testNumber: '2',
              testTitle: 'Extraction Force Test',
              icon: Icons.compress_rounded,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certExtSampleCtrl,
                      hintText: '20 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements',
                      controller: _certExtReqCtrl,
                      hintText: 'Min Force ≥ 200',
                    ),
                  ),
                ],
              ),
            ),

            // 3. Accuracy Test
            _buildCertTestSection(
              testNumber: '3',
              testTitle: 'Accuracy Test',
              icon: Icons.track_changes_outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certAccSampleCtrl,
                      hintText: '30 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements',
                      controller: _certAccReqCtrl,
                      hintText: 'SD ≤ 200 mm',
                    ),
                  ),
                ],
              ),
            ),

            // 4. EPVAT test
            _buildCertTestSection(
              testNumber: '4',
              testTitle: 'EPVAT test (Electronic Pressure, Velocity & Action Time)',
              icon: Icons.speed_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size (+21 °C)',
                      controller: _certEpvSampleCtrl,
                      hintText: '90 rounds',
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildCertInputField(
                          label: '+21 °C Ambient Requirements',
                          controller: _certEpvReq21Ctrl,
                          isMultiline: true,
                          hintText: 'Max Mean Chamber +3SD ≤ 4450 Bar\nMin Mean Port - 3SD ≥ 1030 Bar',
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 2,
                        child: _buildCertFormulaDropdownField(
                          label: '+21 °C Result Formula',
                          controller: _certEpvFormula21Ctrl,
                          temp: '+21',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildCertInputField(
                          label: '+52 °C High Temp Requirements',
                          controller: _certEpvReq52Ctrl,
                          isMultiline: true,
                          hintText: 'Max Mean Chamber ≤ 4550 Bar\nMin Mean Port - 3SD ≥ 1030 Bar',
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 2,
                        child: _buildCertFormulaDropdownField(
                          label: '+52 °C Result Formula',
                          controller: _certEpvFormula52Ctrl,
                          temp: '+52',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildCertInputField(
                          label: '-54 °C Cold Temp Requirements',
                          controller: _certEpvReq54Ctrl,
                          isMultiline: true,
                          hintText: 'Max Mean Chamber ≤ 4550 Bar\nMin Mean Port ≥ 1030 Bar',
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 2,
                        child: _buildCertFormulaDropdownField(
                          label: '-54 °C Result Formula',
                          controller: _certEpvFormula54Ctrl,
                          temp: '-54',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 5. Function Test
            _buildCertTestSection(
              testNumber: '5',
              testTitle: 'Function Test',
              icon: Icons.precision_manufacturing_outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certFuncSampleCtrl,
                      hintText: '500 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements (Multi-line Levels / Limits)',
                      controller: _certFuncReqCtrl,
                      isMultiline: true,
                      hintText: 'Critical Defect 0\nMajor Defects 3\nLevel 3 Defects 6\nLevel 4 Defects 18',
                    ),
                  ),
                ],
              ),
            ),

            // 6. Residual Stress Test
            _buildCertTestSection(
              testNumber: '6',
              testTitle: 'Residual Stress Test',
              icon: Icons.science_outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certRsSampleCtrl,
                      hintText: '50 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements (Zones & Allowed Cracks)',
                      controller: _certRsReqCtrl,
                      isMultiline: true,
                      hintText: 'No. of cracks I zone ≤ 3 Cracks\nNo. of cracks M, L, K, J & S zone = 0 Crack',
                    ),
                  ),
                ],
              ),
            ),

            // 7. Primer Sensitivity Test
            _buildCertTestSection(
              testNumber: '7',
              testTitle: 'Primer Sensitivity Test',
              icon: Icons.bolt_outlined,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: _buildCertInputField(
                      label: 'Sample Size',
                      controller: _certPrimerSampleCtrl,
                      hintText: '175 rounds',
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildCertInputField(
                      label: 'Requirements (H̄ Limits)',
                      controller: _certPrimerReqCtrl,
                      isMultiline: true,
                      hintText: 'H̄+5SD ≤ 450 mm\nH̄-2SD ≥ 75 mm',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8.0),
            SizedBox(
              width: double.infinity,
              height: 42.0,
              child: ElevatedButton.icon(
                onPressed: _handleSaveCertTemplate,
                icon: const Icon(Icons.save_outlined, size: 18.0),
                label: Text(
                  'Save Certificate Template for $_certSelectedCaliber',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertTestSection({
    required String testNumber,
    required String testTitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Icon(icon, size: 16.0, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8.0),
              Text(
                '$testNumber. $testTitle',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          child,
        ],
      ),
    );
  }

  Widget _buildCertInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4.0),
          TextField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12.5,
              fontFamily: 'JetBrainsMono',
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.0),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertFormulaDropdownField({
    required String label,
    required TextEditingController controller,
    required String temp,
  }) {
    final List<Map<String, String>> formulaOptions = [
      {'name': 'None / Default Formula', 'value': ''},
    ];

    try {
      final customFormulas = EpvatFormulaHelper.getFormulasForCaliber(_adminRules, _certSelectedCaliber);
      for (final f in customFormulas) {
        final name = (f['name'] ?? f['formula'] ?? '').toString().trim();
        final formulaStr = (f['formula'] ?? f['name'] ?? '').toString().trim();
        if (name.isNotEmpty && !formulaOptions.any((opt) => opt['value'] == formulaStr || opt['name'] == name)) {
          formulaOptions.add({
            'name': '$name ($formulaStr)',
            'value': formulaStr,
          });
        }
      }
    } catch (_) {}

    final standardFormulas = [
      {'name': 'P1 Mean + 3SD (Mean Chamber + 3SD)', 'value': 'P1 Mean + 3 * P1 SD'},
      {'name': 'P1 Peak Maximum (p1_max)', 'value': 'P1 Max'},
      {'name': 'P1 Mean (mean_chamber)', 'value': 'P1 Mean'},
      {'name': 'P2 Mean - 3SD (Mean Port - 3SD)', 'value': 'P2 Mean - 3 * P2 SD'},
      {'name': 'P2 Minimum (p2_min)', 'value': 'P2 Min'},
      {'name': 'P2 Mean (mean_port)', 'value': 'P2 Mean'},
      {'name': 'Velocity Mean (vel_mean)', 'value': 'Velocity Mean'},
      {'name': 'Action Time Mean (action_time_mean)', 'value': 'Action Time Mean'},
    ];

    for (final sf in standardFormulas) {
      if (!formulaOptions.any((opt) => opt['value'] == sf['value'])) {
        formulaOptions.add(sf);
      }
    }

    final curValue = controller.text.trim();
    if (curValue.isNotEmpty && !formulaOptions.any((opt) => opt['value'] == curValue)) {
      formulaOptions.add({'name': 'Custom: $curValue', 'value': curValue});
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4.0),
          DropdownButtonFormField<String>(
            value: formulaOptions.any((opt) => opt['value'] == curValue) ? curValue : '',
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
                borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
              ),
            ),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12.0,
              fontFamily: 'JetBrainsMono',
            ),
            dropdownColor: Colors.white,
            items: formulaOptions.map((opt) {
              return DropdownMenuItem<String>(
                value: opt['value'],
                child: Text(
                  opt['name']!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: opt['value']!.isEmpty ? 'sans-serif' : 'JetBrainsMono',
                    color: opt['value']!.isEmpty ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                    fontStyle: opt['value']!.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                controller.text = val ?? '';
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
        ),
      );
    }

    if (_currentUserRole == null) {
      return _buildAccessPortal();
    }



    final List<Widget> tabs = [
      DashboardTab(
        currentModule: _currentModule,
        records: _activeRecords,
        onGoToLogs: () => setState(() => _activeTabIndex = 2),
        onClearAllRecords: _handleClearDashboardRecords,
      ),
      EntryTab(
        currentModule: _currentModule,
        onSubmit: _handleNewRecord,
        loggedInUser: _currentUserEmail,
        records: _activeRecords,
        userRole: _currentUserRole?.label ?? 'Operator',
        initialCaliber: _selectedEntryCaliber,
        initialTestName: _selectedEntryTestName,
        onCaliberChanged: (val) => setState(() => _selectedEntryCaliber = val),
        onTestNameChanged: (val) => setState(() => _selectedEntryTestName = val),
        adminRules: _adminRules,
        componentPrimerRecords: _componentTestRecords.where((r) => r.testName == 'Primer Sensitivity Test').toList(),
        componentPropellantRecords: _componentTestRecords.where((r) => r.testName == 'Propellant Test').toList(),
        onOpenEpvatRulesInControl: () {
          setState(() {
            _activeTabIndex = 4; // Controls tab
            _isRulesCardExpanded = true;
            _selectedRuleTest = 'EPVAT Test';
            _ruleSelectedCaliber = _selectedEntryCaliber;
            _ruleSelectedFuncCaliber = _selectedEntryCaliber;
            _ruleSelectedEpvatCaliberForMass = _selectedEntryCaliber;
            _syncRulesControllers();
          });
        },
      ),
      HistoryTab(
        currentModule: _currentModule,
        records: _activeRecords,
        onOpenFolder: _openFolder,
        isAdmin: _currentUserRole == UserRole.admin,
        canEditRecords: _hasPermission('can_edit_records'),
        canDeleteRecords: _hasPermission('can_delete_records'),
        canExportReports: _hasPermission('can_export_reports'),
        onDeleteRecord: _handleDeleteRecord,
        onEditRecord: _handleEditRecord,
        base64Logo: _base64Logo,
        adminRules: _adminRules,
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
        onClearDailyTestLogs: (_currentUserRole == UserRole.admin || _hasPermission('can_clear_logs')) ? _handleClearDailyTestLogs : null,
      ),
      AnalysisRecommendationTab(
        currentModule: _currentModule,
        records: _activeRecords,
        adminRules: _adminRules,
      ),
      _buildControlPanelTab(),
    ];

    Widget mainContent;
    if (_currentModule == 'Lot Acceptance Test' || _currentModule == 'Daily Test' || _currentModule == 'Component Test') {
      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubTabBar(),
          Expanded(child: tabs[_activeTabIndex]),
        ],
      );
    } else if (_currentModule == 'Equipment Report') {
      mainContent = EquipmentReportTab(
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
        isAdmin: _currentUserRole == UserRole.admin,
      );
    } else if (_currentModule == 'Executive Reports') {
      mainContent = ExecutiveReportsTab(
        lotAcceptanceRecords: _records,
        dailyTestRecords: _dailyTestRecords,
        componentTestRecords: _componentTestRecords,
        base64Logo: _base64Logo,
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
      );
    } else if (_currentModule == 'Witness Storage') {
      mainContent = WitnessStorageTab(
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
        userRole: _currentUserRole == UserRole.admin
            ? 'admin'
            : (_currentUserRole == UserRole.technician
                ? 'technician'
                : (_currentUserRole == UserRole.supervisor
                    ? 'supervisor'
                    : (_currentUserRole == UserRole.manager ? 'manager' : 'operator'))),
      );
    } else {
      mainContent = ConsumablesTab(
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
        userRole: _currentUserRole == UserRole.admin ? 'admin' : 'operator',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // DESKTOP LAYOUT WITH AUTO-HIDING SIDEBAR NAVIGATION
          return Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    // Auto-hiding Animated Sidebar
                    MouseRegion(
                      onEnter: (_) => setState(() => _sidebarHovered = true),
                      onExit: (_) => setState(() => _sidebarHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        width: (_sidebarPinned || _sidebarHovered) ? 250.0 : 0.0,
                        child: ClipRect(
                          child: OverflowBox(
                            minWidth: 250.0,
                            maxWidth: 250.0,
                            alignment: Alignment.topLeft,
                            child: Container(
                              width: 250.0,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1C3351),
                                border: Border(right: BorderSide(color: Color(0xFF1E3A8A))),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Sidebar Header Branding with Pin Toggle
                                  SizedBox(
                                    width: double.infinity,
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF263852),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF1E3A8A)),
                                              ),
                                              child: Image.asset(
                                                'assets/logo.png',
                                                height: 136.0,
                                                width: 136.0,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 14.0),
                                            const Text(
                                              'OMPC BALLISTIC',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const Text(
                                              'AERODATA PORTAL',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 9.0,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF38BDF8),
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: IconButton(
                                            icon: Icon(
                                              _sidebarPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                              size: 16.0,
                                              color: _sidebarPinned ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                            ),
                                            tooltip: _sidebarPinned ? 'Unpin Sidebar (Auto-Hide on mouse move)' : 'Pin Sidebar Open',
                                            onPressed: () => setState(() => _sidebarPinned = !_sidebarPinned),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      const SizedBox(height: 18.0),
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF263852),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: const Color(0xFF1E3A8A)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: (_currentUserRole?.color ?? const Color(0xFF0284C7)).withOpacity(0.15),
                              child: Icon(
                                _currentUserRole?.icon ?? Icons.person_rounded,
                                size: 18,
                                color: _currentUserRole?.color ?? const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4.0),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _getTimeBasedGreeting(),
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Active User',
                                    style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: (_currentUserRole?.color ?? const Color(0xFF0284C7)).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _currentUserRole?.label.toUpperCase() ?? 'OPERATOR',
                                      style: TextStyle(
                                        color: _currentUserRole?.color ?? const Color(0xFF0284C7),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      const Text(
                        'LAB MODULES',
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      
                      // Navigation Sidebar Buttons (Modules)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildModuleButton(label: 'Lot Acceptance Test', icon: Icons.verified_outlined, activeColor: const Color(0xFF38BDF8)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Daily Test', icon: Icons.today_outlined, activeColor: const Color(0xFF10B981)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Component Test', icon: Icons.extension_outlined, activeColor: const Color(0xFF38BDF8)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Equipment Report', icon: Icons.construction_outlined, activeColor: const Color(0xFFF59E0B)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Consumable Items', icon: Icons.inventory_2_outlined, activeColor: const Color(0xFFEC4899)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Witness Storage', icon: Icons.archive_outlined, activeColor: const Color(0xFF06B6D4)),
                              const SizedBox(height: 8.0),
                              _buildModuleButton(label: 'Executive Reports', icon: Icons.summarize_outlined, activeColor: const Color(0xFF8B5CF6)),
                            ],
                          ),
                        ),
                      ),

                      // Sidebar Footer with Sign Out and Exit buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'v1.5.1',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.0),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Color(0xFFF59E0B), size: 17.0),
                            onPressed: () {
                              setState(() {
                                _currentUserRole = null;
                              });
                            },
                            tooltip: 'Sign Out / Switch User',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4.0),
                          ),
                          const SizedBox(width: 4.0),
                          IconButton(
                            icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 19.0),
                            onPressed: () => _confirmExitApp(context),
                            tooltip: 'Exit Application',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4.0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

                // ACTIVE SCREEN PANEL (Full width when sidebar auto-hides)
                Expanded(
                  child: Container(
                    color: const Color(0xFFC4D6EC),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: mainContent,
                    ),
                  ),
                ),
              ],
            ),
            // Left hover detection strip to reveal sidebar when auto-hidden
            if (!_sidebarPinned && !_sidebarHovered)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 20.0,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _sidebarHovered = true),
                  child: Container(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 4.0,
                        height: 54.0,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.55),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4.0),
                            bottomRight: Radius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
        } else {
          // MOBILE LAYOUT WITH APP BAR DROPDOWN (Responsive, no overflow)
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF1C3351),
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
              title: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _currentModule,
                  dropdownColor: const Color(0xFF1C3351),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8), size: 20.0),
                  isDense: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  onChanged: (String? val) {
                    if (val != null) {
                      setState(() {
                        _currentModule = val;
                        _activeTabIndex = 0;
                      });
                      _storageService.saveActiveModule(val);
                    }
                  },
                  items: [
                    'Lot Acceptance Test',
                    'Daily Test',
                    'Component Test',
                    'Equipment Report',
                    'Consumable Items',
                    'Witness Storage',
                    'Executive Reports',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 13.0)),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                // Live ticking digital clock (Compact Mobile AppBar)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                    margin: const EdgeInsets.only(right: 6.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C415E),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 11.0, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 3.0),
                        Text(
                          _formatLiveClock(_currentTime),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: Color(0xFF38BDF8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Mobile Options & Profile Menu
                PopupMenuButton<String>(
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: (_currentUserRole?.color ?? const Color(0xFF38BDF8)).withOpacity(0.2),
                    child: Icon(
                      _currentUserRole?.icon ?? Icons.more_vert,
                      size: 16,
                      color: _currentUserRole?.color ?? const Color(0xFF38BDF8),
                    ),
                  ),
                  color: const Color(0xFF1C3351),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                  ),
                  onSelected: (val) {
                    if (val == 'toggle_alerts') {
                      setState(() {
                        _submissionAlertsEnabled = !_submissionAlertsEnabled;
                        _adminRules['submission_alerts_enabled'] = _submissionAlertsEnabled;
                      });
                      _storageService.saveRules(_adminRules);
                    } else if (val == 'sign_out') {
                      setState(() {
                        _currentUserRole = null;
                      });
                    } else if (val == 'exit_app') {
                      _confirmExitApp(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Active User',
                            style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _currentUserRole?.label.toUpperCase() ?? 'OPERATOR',
                            style: TextStyle(
                              color: _currentUserRole?.color ?? const Color(0xFF38BDF8),
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(color: Color(0xFF1E3A8A)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_alerts',
                      child: Row(
                        children: [
                          Icon(
                            _submissionAlertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                            color: _submissionAlertsEnabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            size: 18.0,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            _submissionAlertsEnabled ? 'Submission Alerts (ON)' : 'Submission Alerts (OFF)',
                            style: const TextStyle(color: Colors.white, fontSize: 12.0),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sign_out',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Color(0xFFF59E0B), size: 18.0),
                          SizedBox(width: 8.0),
                          Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 12.0)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'exit_app',
                      child: Row(
                        children: [
                          Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 18.0),
                          SizedBox(width: 8.0),
                          Text('Exit App', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.0)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6.0),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: (_currentModule == 'Lot Acceptance Test' || _currentModule == 'Daily Test' || _currentModule == 'Component Test')
                  ? tabs[_activeTabIndex]
                  : mainContent,
            ),
            bottomNavigationBar: (_currentModule == 'Lot Acceptance Test' || _currentModule == 'Daily Test' || _currentModule == 'Component Test')
                ? BottomNavigationBar(
                    currentIndex: _activeTabIndex,
                    onTap: (index) => setState(() => _activeTabIndex = index),
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: const Color(0xFF1C3351),
                    selectedItemColor: const Color(0xFF38BDF8),
                    unselectedItemColor: const Color(0xFF94A3B8),
                    selectedFontSize: 11.5,
                    unselectedFontSize: 11.5,
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                      BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Log Entry'),
                      BottomNavigationBarItem(icon: Icon(Icons.table_chart_outlined), label: 'Logs'),
                      BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'AI Advisory'),
                      BottomNavigationBarItem(icon: Icon(Icons.settings_input_component_outlined), label: 'Controls'),
                    ],
                  )
                : null,
          );
        }
      },
    );
  }

  Widget _buildModuleButton({required String label, required IconData icon, required Color activeColor}) {
    final bool isActive = _currentModule == label;
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => setState(() {
          _currentModule = label;
          _activeTabIndex = 0; // Reset sub-tab
          _storageService.saveActiveModule(label);
        }),
        icon: Icon(icon, color: isActive ? activeColor : const Color(0xFF38BDF8), size: 18.0),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13.0,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          backgroundColor: isActive ? const Color(0xFF344D6E) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: isActive ? const Color(0xFF1E3A8A) : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabBar() {
    final List<Map<String, dynamic>> subTabs = [
      {'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
      {'label': 'Log Entry', 'icon': Icons.add_circle_outline},
      {'label': 'Inspection Logs', 'icon': Icons.table_chart_outlined},
      {'label': 'Analysis & Recommendations', 'icon': Icons.auto_awesome},
      {'label': 'Controls', 'icon': Icons.settings_input_component_outlined},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFB8CEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E3A8A),
            blurRadius: 14.0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Subtabs Navigation
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(subTabs.length, (index) {
                  final bool isActive = _activeTabIndex == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _activeTabIndex = index),
                      icon: Icon(
                        subTabs[index]['icon'],
                        size: 15.0,
                        color: isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                      label: Text(
                        subTabs[index]['label'],
                        style: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        backgroundColor: isActive ? const Color(0xFF4D99DB) : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(
                            color: isActive ? const Color(0xFF4D99DB) : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12.0),

          // Header Badges: Welcome Greeting, Live Ticking Digital Clock, Alerts Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Welcome greeting with user's name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FB),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFFB8CEE5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👋', style: TextStyle(fontSize: 12.0)),
                    const SizedBox(width: 6.0),
                    Text(
                      'Welcome, ${_currentUserEmail.isNotEmpty ? _currentUserEmail : 'User'}!',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // Live ticking digital clock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FB),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFFB8CEE5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14.0, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6.0),
                    Text(
                      _formatLiveClock(_currentTime),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: Color(0xFF0284C7),
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // Alerts toggle button
              InkWell(
                onTap: () {
                  setState(() {
                    _submissionAlertsEnabled = !_submissionAlertsEnabled;
                    _adminRules['submission_alerts_enabled'] = _submissionAlertsEnabled;
                  });
                  _storageService.saveRules(_adminRules);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF0F172A),
                      content: Text(
                        _submissionAlertsEnabled ? 'Submission alerts enabled' : 'Submission alerts turned off',
                        style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: _submissionAlertsEnabled ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFF1F6FB),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: _submissionAlertsEnabled ? const Color(0xFF10B981) : const Color(0xFFB8CEE5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _submissionAlertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        size: 15.0,
                        color: _submissionAlertsEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        _submissionAlertsEnabled ? 'Alerts: ON' : 'Alerts: OFF',
                        style: TextStyle(
                          color: _submissionAlertsEnabled ? const Color(0xFF059669) : const Color(0xFF475569),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModulePlaceholder(String name, IconData icon, Color color) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550.0),
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFB8CEE5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1E3A8A),
              blurRadius: 20.0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 48.0),
            ),
            const SizedBox(height: 24.0),
            Text(
              name.toUpperCase(),
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Module Initialized',
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'This laboratory workspace has been initialized successfully. The underlying database schemas and platform hooks are ready.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Pending development details for active trials and workflow spec sheets.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.0, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
