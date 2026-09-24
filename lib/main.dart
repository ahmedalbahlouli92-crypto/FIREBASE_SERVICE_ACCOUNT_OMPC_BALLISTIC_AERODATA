import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'services/storage_service.dart';
import 'models/ballistic_record.dart';
import 'services/attachment_helper.dart';
import 'screens/dashboard_tab.dart';
import 'screens/entry_tab.dart';
import 'screens/history_tab.dart';
import 'screens/analysis_recommendation_tab.dart';
import 'screens/consumables_tab.dart';
import 'screens/executive_reports_tab.dart';
import 'services/epvat_formula_helper.dart';
import 'services/supabase_service.dart';
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

class OmpcBallisticAeroDataApp extends StatelessWidget {
  const OmpcBallisticAeroDataApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMPC Ballistic AeroData',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF263852),
        primaryColor: const Color(0xFF31B9F6),
        cardColor: const Color(0xFF344D6E),
        canvasColor: const Color(0xFF2C415E),
        dialogBackgroundColor: const Color(0xFF344D6E),
        fontFamily: 'Outfit',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF31B9F6),
          secondary: Color(0xFF5FC9F8),
          surface: Color(0xFF344D6E),
          onPrimary: Colors.white,
          onSurface: Colors.white,
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
  ],
  'epvat_barrels': [
    'EPVAT-B-201',
    'EPVAT-B-202',
    'EPVAT-B-203',
  ],
  'gp6_serials': [
    'GP2-PCB-9901',
    'GP2-PCB-9902',
  ],
  'weapons': [
    {'type': 'M4A1 Carbine', 'serial': 'W-9012'},
    {'type': 'M16A4 Rifle', 'serial': 'W-9015'},
    {'type': 'M249 SAW', 'serial': 'W-4401'},
    {'type': 'G3A3 Rifle', 'serial': 'W-7721'},
  ],
  'gp_transducers': {
    'gp1': [
      'GP1-001 (PCB 119B)',
      'GP1-002 (PCB 119B)',
      'GP1-003 (PCB 119B)',
    ],
    'gp2': [
      'GP2-001 (PCB 119B)',
      'GP2-002 (PCB 119B)',
      'GP2-003 (PCB 119B)',
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
  'primer_sensitivity': {
    'drop_weight_grams': 55.0,
    'instructions': 'Run-Down / Bruceton Primer Sensitivity Test: Drop steel ball onto primed cases at specified heights.',
    'calibers': {
      '5.56x45 SS109': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 380.0,
        'max_no_fire_height': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '5.56 SS109: 55g ball drop. All-fire at Hbar + 5S <= H_max; All-no-fire at Hbar - 2S >= H_min.',
      },
      '5.56x45 M193': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 380.0,
        'max_no_fire_height': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '5.56 M193: 55g ball drop sensitivity test.',
      },
      '7.62x51 M80': {
        'drop_weight_grams': 111.7,
        'min_all_fire_height': 400.0,
        'max_no_fire_height': 80.0,
        'hbar_min': 160.0,
        'hbar_max': 320.0,
        'max_sd': 65.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '7.62 M80: 111.7g ball drop sensitivity test.',
      },
      '9x19mm Para': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 350.0,
        'max_no_fire_height': 70.0,
        'hbar_min': 140.0,
        'hbar_max': 280.0,
        'max_sd': 55.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': '9x19mm Para: Boxer primer drop ball test.',
      },
      'default': {
        'drop_weight_grams': 55.0,
        'min_all_fire_height': 380.0,
        'max_no_fire_height': 75.0,
        'hbar_min': 150.0,
        'hbar_max': 300.0,
        'max_sd': 60.0,
        'retest_misfires': 1,
        'reject_misfires': 2,
        'instructions': 'Standard Primer Sensitivity Test.',
      }
    }
  },
  'function_test': {
    'weapons': [
      'M4A1 Carbine',
      'M16A4 Rifle',
      'G3A3 Rifle',
      'MP5A3 Submachine Gun',
      'Beretta M9 Pistol',
      'M249 SAW',
    ],
    'classification_image': '',
    'calibers': {
      '5.56x45 SS109': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Perforated primer, Bullet lodged in bore',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Failure to feed, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case dent, Minor extractor mark, Light primer indentation',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Superficial scratches, Minor cosmetic blemish, Slight discoloration',
        },
      },
      '5.56x45 M193': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Perforated primer, Bullet lodged in bore',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Failure to feed, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case dent, Minor extractor mark, Light primer indentation',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Superficial scratches, Minor cosmetic blemish, Slight discoloration',
        },
      },
      '5.56x45 M200 Blank': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Case rupture, Plug dislodged, Misfire',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to cycle, Failure to eject, Short recoil, Double feed',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Rose petal crimp tear, Mouth deformity, Minor denting',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Cosmetic discoloration, Scratches on blank body',
        },
      },
      '7.62x51 M80': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Perforated primer, Bullet lodged in bore',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Failure to feed, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case dent, Minor extractor mark, Light primer indentation',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Superficial scratches, Minor cosmetic blemish, Slight discoloration',
        },
      },
      '7.62x51 M82': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Case rupture, Rosette petal separation',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to cycle, Failure to feed, Failure to extract',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Crimp damage, Sluggish extraction, Minor deformation',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Surface scratches, Slight tarnish',
        },
      },
      '7.62x51 M62 Tracer': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Bullet lodged in bore, Blind tracer',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Failure to feed, Short trace',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case dent, Extractor mark, Light primer strike',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Cosmetic markings, Scratches',
        },
      },
      '9x19mm Parabellum': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Perforated primer, Squib load',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Stovepipe, Failure to extract, Failure to feed, Misfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Rim burr, Light primer mark, Case mouth ding',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Minor scratch, Slight surface tarnish',
        },
      },
      '12.7x99 NATO': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case head, Perforated primer, Squib',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case body dent, Extractor mark, Rim dent',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Surface scratching, Minor cosmetic blemish',
        },
      },
      'default': {
        'level1': {
          'max_allowed': 0,
          'description': 'Blown primer, Split case, Perforated primer, Bullet lodged in bore',
        },
        'level2': {
          'max_allowed': 0,
          'description': 'Failure to extract, Failure to eject, Failure to feed, Misfeed, Hangfire',
        },
        'level3': {
          'max_allowed': 2,
          'description': 'Mild case dent, Minor extractor mark, Light primer indentation',
        },
        'level4': {
          'max_allowed': 5,
          'description': 'Superficial scratches, Minor cosmetic blemish, Slight discoloration',
        },
      },
    },
    'level1': {
      'max_allowed': 0,
      'description': 'Blown primer, Split case, Perforated primer, Bullet lodged in bore',
    },
    'level2': {
      'max_allowed': 0,
      'description': 'Failure to extract, Failure to eject, Failure to feed, Misfeed, Hangfire',
    },
    'level3': {
      'max_allowed': 2,
      'description': 'Mild case dent, Minor extractor mark, Light primer indentation',
    },
    'level4': {
      'max_allowed': 5,
      'description': 'Superficial scratches, Minor cosmetic blemish, Slight discoloration',
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
  final TextEditingController _newPrimerSupplierCtrl = TextEditingController();
  final TextEditingController _newPropellantSupplierCtrl = TextEditingController();
  final TextEditingController _newPropellantCodeCtrl = TextEditingController();
  final TextEditingController _newWeaponTypeInputCtrl = TextEditingController();
  final TextEditingController _newWeaponSerialInputCtrl = TextEditingController();
  String _selectedAdminWeaponType = 'Pistol';
  String _selectedAdminWeaponManufacturer = 'Beretta';
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

  // Weapons rule controllers
  final TextEditingController _ruleNewWeaponNameCtrl = TextEditingController();
  String _ruleNewWeaponType = 'Loose'; // 'Loose' or 'Linked'
  final TextEditingController _ruleNewWeaponMinRpmCtrl = TextEditingController();
  final TextEditingController _ruleNewWeaponMaxRpmCtrl = TextEditingController();

  // Function Test rule controllers
  String _ruleSelectedFuncCaliber = '5.56x45 SS109';
  final TextEditingController _ruleFuncL1MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL1DescCtrl = TextEditingController();
  final TextEditingController _ruleFuncL2MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL2DescCtrl = TextEditingController();
  final TextEditingController _ruleFuncL3MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL3DescCtrl = TextEditingController();
  final TextEditingController _ruleFuncL4MaxCtrl = TextEditingController();
  final TextEditingController _ruleFuncL4DescCtrl = TextEditingController();
  final TextEditingController _ruleNewFuncWeaponCtrl = TextEditingController();

  void _loadFunctionCaliberRules(String caliber) {
    final func = _adminRules['function_test'] ?? {};
    final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
    final calRules = Map<String, dynamic>.from(calibersMap[caliber] ?? calibersMap['default'] ?? func);
    
    final l1 = calRules['level1'] ?? func['level1'] ?? {};
    final l2 = calRules['level2'] ?? func['level2'] ?? {};
    final l3 = calRules['level3'] ?? func['level3'] ?? {};
    final l4 = calRules['level4'] ?? func['level4'] ?? {};

    _ruleFuncL1MaxCtrl.text = (l1['max_allowed'] ?? 0).toString();
    _ruleFuncL1DescCtrl.text = (l1['description'] ?? 'Blown primer, Split case, Perforated primer, Bullet lodged in bore').toString();

    _ruleFuncL2MaxCtrl.text = (l2['max_allowed'] ?? 0).toString();
    _ruleFuncL2DescCtrl.text = (l2['description'] ?? 'Failure to extract, Failure to eject, Misfeed, Hangfire').toString();

    _ruleFuncL3MaxCtrl.text = (l3['max_allowed'] ?? 2).toString();
    _ruleFuncL3DescCtrl.text = (l3['description'] ?? 'Mild case dent, Minor extractor mark, Light primer indentation').toString();

    _ruleFuncL4MaxCtrl.text = (l4['max_allowed'] ?? 5).toString();
    _ruleFuncL4DescCtrl.text = (l4['description'] ?? 'Superficial scratches, Minor cosmetic blemish, Slight discoloration').toString();
  }

  void _saveCurrentFunctionCaliberRules() {
    final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
    final calibersMap = Map<String, dynamic>.from(func['calibers'] ?? {});
    
    final currentRules = {
      'level1': {
        'max_allowed': int.tryParse(_ruleFuncL1MaxCtrl.text.trim()) ?? 0,
        'description': _ruleFuncL1DescCtrl.text.trim(),
      },
      'level2': {
        'max_allowed': int.tryParse(_ruleFuncL2MaxCtrl.text.trim()) ?? 0,
        'description': _ruleFuncL2DescCtrl.text.trim(),
      },
      'level3': {
        'max_allowed': int.tryParse(_ruleFuncL3MaxCtrl.text.trim()) ?? 2,
        'description': _ruleFuncL3DescCtrl.text.trim(),
      },
      'level4': {
        'max_allowed': int.tryParse(_ruleFuncL4MaxCtrl.text.trim()) ?? 5,
        'description': _ruleFuncL4DescCtrl.text.trim(),
      },
    };

    calibersMap[_ruleSelectedFuncCaliber] = currentRules;
    func['calibers'] = calibersMap;
    func['level1'] = currentRules['level1'];
    func['level2'] = currentRules['level2'];
    func['level3'] = currentRules['level3'];
    func['level4'] = currentRules['level4'];

    _adminRules['function_test'] = func;
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _clockTimer?.cancel();
    _welcomeDismissTimer?.cancel();
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
    _ruleEpvInstructionsCtrl.text = (calEpv['instructions'] ?? epv['instructions'] ?? 'Ensure P1 Chamber does not exceed limits, and P2 Port remains above minimums.').toString();

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
    primerCalibers[_ruleSelectedCaliber] = {
      'drop_weight_grams': double.tryParse(_rulePrimerDropWeightCtrl.text.trim()) ?? 55.0,
      'min_all_fire_height': double.tryParse(_rulePrimerMinAllFireCtrl.text.trim()) ?? 380.0,
      'max_no_fire_height': double.tryParse(_rulePrimerMaxNoFireCtrl.text.trim()) ?? 75.0,
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
    // Live ticking digital clock timer (Instruction 19)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    // Live background data sync across all users without stopping or refreshing the app
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _syncRecordsSilently();
    });
  }

  Future<void> _syncRecordsSilently() async {
    try {
      final recordsList = await _storageService.loadRecords(module: 'Lot Acceptance Test');
      final dailyList = await _storageService.loadRecords(module: 'Daily Test');
      final componentList = await _storageService.loadRecords(module: 'Component Test');
      if (mounted) {
        setState(() {
          _records = recordsList;
          _dailyTestRecords = dailyList;
          _componentTestRecords = componentList;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
      _base64Logo = base64Encode(logoBytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
    
    try {
      final headerBytes = await rootBundle.load('assets/report_header.png');
      _base64ReportHeader = base64Encode(headerBytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading report header: $e");
    }
    
    try {
      final dirPath = await _storageService.getDirectoryPath();
      final opsList = await _storageService.loadOperators();
      final rules = await _storageService.loadRules();
      final Map<String, dynamic> activeRules = rules.isEmpty ? Map<String, dynamic>.from(_defaultRules) : rules;
      
      // Safe schema migration: populate missing sections or keys
      if (activeRules['waterproof'] == null) {
        activeRules['waterproof'] = Map<String, dynamic>.from(_defaultRules['waterproof']);
      } else {
        final wp = Map<String, dynamic>.from(activeRules['waterproof'] as Map);
        if (wp['calibers'] == null) {
          wp['calibers'] = Map<String, dynamic>.from(_defaultRules['waterproof']['calibers']);
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['waterproof']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(wp['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) cur[k] = v; });
          wp['calibers'] = cur;
        }
        activeRules['waterproof'] = wp;
      }
      if (activeRules['residual_stress'] == null) {
        activeRules['residual_stress'] = Map<String, dynamic>.from(_defaultRules['residual_stress']);
      } else {
        final rs = Map<String, dynamic>.from(activeRules['residual_stress'] as Map);
        if (rs['classification_image'] == null) rs['classification_image'] = '';
        if (rs['calibers'] == null) {
          rs['calibers'] = Map<String, dynamic>.from(_defaultRules['residual_stress']['calibers']);
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['residual_stress']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(rs['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) cur[k] = v; });
          rs['calibers'] = cur;
        }
        activeRules['residual_stress'] = rs;
      }
      if (activeRules['extraction'] == null) {
        activeRules['extraction'] = Map<String, dynamic>.from(_defaultRules['extraction']);
      } else {
        final ext = Map<String, dynamic>.from(activeRules['extraction'] as Map);
        if (ext['calibers'] == null) {
          ext['calibers'] = Map<String, dynamic>.from(_defaultRules['extraction']['calibers']);
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['extraction']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(ext['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) cur[k] = v; });
          ext['calibers'] = cur;
        }
        activeRules['extraction'] = ext;
      }
      if (activeRules['accuracy'] == null) {
        activeRules['accuracy'] = Map<String, dynamic>.from(_defaultRules['accuracy']);
      } else {
        final acc = Map<String, dynamic>.from(activeRules['accuracy'] as Map);
        final defaultLimits = Map<String, dynamic>.from(_defaultRules['accuracy']['limits'] ?? {});
        final curLimits = Map<String, dynamic>.from(acc['limits'] ?? {});
        defaultLimits.forEach((k, v) {
          if (!curLimits.containsKey(k)) curLimits[k] = v;
        });
        acc['limits'] = curLimits;
        activeRules['accuracy'] = acc;
      }
      if (activeRules['epvat'] == null) {
        activeRules['epvat'] = Map<String, dynamic>.from(_defaultRules['epvat']);
      } else {
        final epv = Map<String, dynamic>.from(activeRules['epvat'] as Map);
        if (epv['custom_formulas'] == null) {
          epv['custom_formulas'] = <String, dynamic>{};
        }
        if (epv['bullet_mass_grams'] == null) {
          epv['bullet_mass_grams'] = Map<String, dynamic>.from(_defaultRules['epvat']['bullet_mass_grams']);
        }
        if (epv['limits_by_caliber'] == null) {
          epv['limits_by_caliber'] = Map<String, dynamic>.from(_defaultRules['epvat']['limits_by_caliber']);
        } else {
          final defaultLimits = Map<String, dynamic>.from(_defaultRules['epvat']['limits_by_caliber'] ?? {});
          final curLimits = Map<String, dynamic>.from(epv['limits_by_caliber'] as Map);
          defaultLimits.forEach((k, v) {
            if (!curLimits.containsKey(k)) curLimits[k] = v;
          });
          epv['limits_by_caliber'] = curLimits;
        }
        activeRules['epvat'] = epv;
      }
      if (activeRules['cyclic_rate'] == null || activeRules['cyclic_rate']['weapons'] == null) {
        activeRules['cyclic_rate'] = Map<String, dynamic>.from(_defaultRules['cyclic_rate']);
      }
      if (activeRules['barrel_serial_numbers'] == null) {
        activeRules['barrel_serial_numbers'] = List<String>.from(_defaultRules['barrel_serial_numbers']);
      } else {
        activeRules['barrel_serial_numbers'] = List<String>.from(activeRules['barrel_serial_numbers'] as List);
      }
      if (activeRules['accuracy_barrels'] == null) {
        activeRules['accuracy_barrels'] = List<String>.from(_defaultRules['accuracy_barrels']);
      } else {
        activeRules['accuracy_barrels'] = List<String>.from(activeRules['accuracy_barrels'] as List);
      }
      if (activeRules['epvat_barrels'] == null) {
        activeRules['epvat_barrels'] = List<String>.from(_defaultRules['epvat_barrels']);
      } else {
        activeRules['epvat_barrels'] = List<String>.from(activeRules['epvat_barrels'] as List);
      }
      if (activeRules['gp6_serials'] == null) {
        activeRules['gp6_serials'] = List<String>.from(_defaultRules['gp6_serials']);
      } else {
        activeRules['gp6_serials'] = List<String>.from(activeRules['gp6_serials'] as List);
      }
      if (activeRules['weapons'] == null) {
        activeRules['weapons'] = List<Map<String, dynamic>>.from(
          (_defaultRules['weapons'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
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
      } else {
        final gp = Map<String, dynamic>.from(activeRules['gp_transducers'] as Map);
        if (gp['gp1'] == null) gp['gp1'] = List<String>.from(_defaultRules['gp_transducers']['gp1']);
        if (gp['gp2'] == null) gp['gp2'] = List<String>.from(_defaultRules['gp_transducers']['gp2']);
        activeRules['gp_transducers'] = gp;
      }
      if (activeRules['function_test'] == null) {
        activeRules['function_test'] = Map<String, dynamic>.from(_defaultRules['function_test']);
      } else {
        final func = Map<String, dynamic>.from(activeRules['function_test'] as Map);
        if (func['weapons'] == null) {
          func['weapons'] = List<String>.from(_defaultRules['function_test']['weapons']);
        }
        if (func['calibers'] == null) {
          func['calibers'] = Map<String, dynamic>.from(_defaultRules['function_test']['calibers']);
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
      } else {
        final pr = Map<String, dynamic>.from(activeRules['primer_sensitivity'] as Map);
        if (pr['calibers'] == null) {
          pr['calibers'] = Map<String, dynamic>.from(_defaultRules['primer_sensitivity']['calibers']);
        } else {
          final def = Map<String, dynamic>.from(_defaultRules['primer_sensitivity']['calibers'] ?? {});
          final cur = Map<String, dynamic>.from(pr['calibers'] as Map);
          def.forEach((k, v) { if (!cur.containsKey(k)) cur[k] = v; });
          pr['calibers'] = cur;
        }
        activeRules['primer_sensitivity'] = pr;
      }

      if (activeRules['role_permissions'] == null) {
        activeRules['role_permissions'] = Map<String, dynamic>.from(_defaultRules['role_permissions']);
      } else {
        final curPerms = Map<String, dynamic>.from(activeRules['role_permissions'] as Map);
        final defPerms = Map<String, dynamic>.from(_defaultRules['role_permissions'] as Map);
        defPerms.forEach((role, perms) {
          if (!curPerms.containsKey(role)) {
            curPerms[role] = Map<String, dynamic>.from(perms as Map);
          } else {
            final curRoleMap = Map<String, dynamic>.from(curPerms[role] as Map);
            (perms as Map).forEach((pk, pv) {
              if (!curRoleMap.containsKey(pk)) curRoleMap[pk] = pv;
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
      } else {
        activeRules['primer_suppliers'] = List<String>.from(activeRules['primer_suppliers'] as List);
      }
      if (activeRules['propellant_suppliers'] == null) {
        activeRules['propellant_suppliers'] = List<String>.from(_defaultRules['propellant_suppliers']);
      } else {
        activeRules['propellant_suppliers'] = List<String>.from(activeRules['propellant_suppliers'] as List);
      }
      if (activeRules['propellant_codes'] == null) {
        activeRules['propellant_codes'] = List<String>.from(_defaultRules['propellant_codes']);
      } else {
        activeRules['propellant_codes'] = List<String>.from(activeRules['propellant_codes'] as List);
      }

      // Save rules back to write out any migrated schemas
      await _storageService.saveRules(activeRules);
      
      final recordsList = await _storageService.loadRecords(module: 'Lot Acceptance Test');
      final dailyList = await _storageService.loadRecords(module: 'Daily Test');
      final componentList = await _storageService.loadRecords(module: 'Component Test');
      final savedModule = _storageService.loadActiveModule();

      setState(() {
        if (savedModule != null && savedModule.isNotEmpty) {
          _currentModule = savedModule;
        }
        _records = recordsList;
        _dailyTestRecords = dailyList;
        _componentTestRecords = componentList;
        _storagePath = path;
        _operators = opsList;
        _adminRules = activeRules;
        _submissionAlertsEnabled = activeRules['submission_alerts_enabled'] == true;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading initial data: $e");
      setState(() {
        _storagePath = 'Error loading directory';
        _isLoading = false;
      });
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
    await _storageService.saveRecord(record, module: _currentModule);
    final updated = await _storageService.loadRecords(module: _currentModule);
    setState(() {
      if (_currentModule == 'Lot Acceptance Test') {
        _records = updated;
      } else if (_currentModule == 'Component Test') {
        _componentTestRecords = updated;
      } else {
        _dailyTestRecords = updated;
      }
    });

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
      return 'Alsalamu Alaikum - Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Alsalamu Alaikum - Good Afternoon';
    } else {
      return 'Alsalamu Alaikum - Good Evening';
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
        _welcomeDismissTimer = Timer(const Duration(milliseconds: 3200), () {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_rounded, color: Color(0xFF38BDF8), size: 16.0),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Text(
                          _getTimeBasedGreeting(),
                          style: const TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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
        _activeTabIndex = (role == UserRole.admin) ? 0 : 1;
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
          r.lotNumber == record.lotNumber && 
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
          content: Text('Quality entry deleted successfully.'),
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
      if (_currentModule == 'Lot Acceptance Test') {
        final idx = _records.indexWhere((r) =>
          (original.id != null && original.id!.isNotEmpty && r.id == original.id) ||
          (r.timestamp == original.timestamp &&
           r.lotNumber == original.lotNumber &&
           r.produced == original.produced &&
           r.defects == original.defects)
        );
        if (idx != -1) _records[idx] = updated;
      } else if (_currentModule == 'Component Test') {
        final idx = _componentTestRecords.indexWhere((r) =>
          (original.id != null && original.id!.isNotEmpty && r.id == original.id) ||
          (r.timestamp == original.timestamp &&
           r.lotNumber == original.lotNumber &&
           r.produced == original.produced &&
           r.defects == original.defects)
        );
        if (idx != -1) _componentTestRecords[idx] = updated;
      } else {
        final idx = _dailyTestRecords.indexWhere((r) =>
          (original.id != null && original.id!.isNotEmpty && r.id == original.id) ||
          (r.timestamp == original.timestamp &&
           r.lotNumber == original.lotNumber &&
           r.produced == original.produced &&
           r.defects == original.defects)
        );
        if (idx != -1) _dailyTestRecords[idx] = updated;
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
          const Text(
            'Lab Control & Settings',
            style: TextStyle(
              fontSize: 26.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4.0),
          const Text(
            'Native desktop hooks and reporting folder configurations',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF8E96A3),
            ),
          ),
          const SizedBox(height: 24.0),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 750
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
                  
              return Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                children: [
                  // Workspace Settings Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF344D6E),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          blurRadius: 16.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Workspace Logs',
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12.0),
                        const Text(
                          'Ballistic trial outcomes are logged to high-fidelity CSV files. These files are stored in your documents directory for integration with other analytics suites.',
                          style: TextStyle(fontSize: 13.0, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                        const SizedBox(height: 20.0),
                        Text(
                          'Target Path:\n$_storagePath',
                          style: const TextStyle(fontSize: 12.0, color: Color(0xFF38BDF8), fontFamily: 'JetBrainsMono'),
                        ),
                        const SizedBox(height: 24.0),
                        if (isDesktop && _currentUserRole == UserRole.admin)
                          SizedBox(
                            width: double.infinity,
                            height: 40.0,
                            child: ElevatedButton.icon(
                              onPressed: _openFolder,
                              icon: const Icon(Icons.folder_open, size: 18.0),
                              label: const Text('Open Logs Directory'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
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
                    ),
                  ),
                  
                  // Diagnostics Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF344D6E),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          blurRadius: 16.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Diagnostics',
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16.0),
                        _buildDiagnosticItem('Operating System', kIsWeb ? 'BROWSER' : Platform.operatingSystem.toUpperCase()),
                        _buildDiagnosticItem('Execution Host', 'Flutter Native Engine'),
                        _buildDiagnosticItem('Database Source', 'Local Flatfile (CSV)'),
                        _buildDiagnosticItem('Daily Report File', _storageService.getDailyFileName()),
                        _buildDiagnosticItem('Local Port Binding', 'None (Native Embedded Storage)'),
                      ],
                    ),
                  ),

                  // Personnel & Role Management (Admin only)
                  if (_currentUserRole == UserRole.admin)
                    _buildOperatorManagementCard(cardWidth),

                  // Role Permissions & Access Matrix (Admin only)
                  if (_currentUserRole == UserRole.admin)
                    _buildRolePermissionsCard(cardWidth),
                  
                  // Equipment Fleet & Round Tracking (Admin only)
                  if (_currentUserRole == UserRole.admin)
                    _buildEquipmentFleetCard(cardWidth),

                  // Rules Management (Admin only or authorized roles)
                  if (_currentUserRole == UserRole.admin || _hasPermission('can_manage_rules'))
                    _buildRulesManagementCard(cardWidth),
                ],
              );
            },
          ),
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
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF38BDF8), size: 20.0),
              ),
              const SizedBox(width: 12.0),
              const Expanded(
                child: Text(
                  'Personnel & Role Management (4 Tiers)',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Admin defines authorized lab personnel across 4 operational levels: Manager, Supervisor, Technician, and Operator. Personnel log in with their credentials to access the laboratory workspace.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
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
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 20.0),
              ),
              const SizedBox(width: 12.0),
              const Expanded(
                child: Text(
                  'Role Permissions & Access Matrix',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Admin can grant permissions to specific roles (e.g., Supervisor can edit the data on the report if there is some mistake, delete records, or manage rules). Toggle permissions below; changes are saved and applied immediately.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
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
    final gp6List = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
    final epvatBarrels = List<String>.from(_adminRules['epvat_barrels'] as List<dynamic>? ?? []);
    final accBarrels = List<String>.from(_adminRules['accuracy_barrels'] as List<dynamic>? ?? []);
    final primerSuppliers = List<String>.from(_adminRules['primer_suppliers'] as List<dynamic>? ?? []);
    final propellantSuppliers = List<String>.from(_adminRules['propellant_suppliers'] as List<dynamic>? ?? []);
    final propellantCodes = List<String>.from(_adminRules['propellant_codes'] as List<dynamic>? ?? []);

    return Container(
      width: width,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF38BDF8), size: 20.0),
              ),
              const SizedBox(width: 12.0),
              const Expanded(
                child: Text(
                  'Equipment Fleet & Cumulative Round Tracking',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Text(
            'Admin enters Weapon Types & Serials, GP6 Serial Numbers, EPVAT Barrel Serials, and Accuracy Barrel Serials. The system automatically tracks cumulative rounds fired through each asset.',
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
                        final type = model.isNotEmpty ? '$mfg $model ($weaponType)' : '$mfg $weaponType';
                        final serial = _newWeaponSerialInputCtrl.text.trim();
                        if (type.isEmpty) return;
                        final list = List<Map<String, dynamic>>.from(
                          (_adminRules['weapons'] as List<dynamic>? ?? []).map((e) {
                            if (e is Map) return Map<String, dynamic>.from(e);
                            return {'type': e.toString(), 'serial': ''};
                          }),
                        );
                        list.add({'type': type, 'serial': serial, 'category': weaponType, 'manufacturer': mfg});
                        _adminRules['weapons'] = list;

                        // Also add to function_test weapons list if not present
                        final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                        final funcWeapons = List<String>.from(func['weapons'] ?? []);
                        final fullLabel = serial.isNotEmpty ? '$type (SN: $serial)' : type;
                        if (!funcWeapons.contains(fullLabel)) {
                          funcWeapons.add(fullLabel);
                          func['weapons'] = funcWeapons;
                          _adminRules['function_test'] = func;
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
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
          const SizedBox(height: 18.0),

          // 2. GP2 (PORT) TRANSDUCER SERIAL NUMBERS
          _buildAssetCategoryHeader('GP2 (Port) Transducer Serial Numbers (EPVAT)', Icons.sensors_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newGP6SerialCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                  decoration: InputDecoration(
                    hintText: 'GP2 Serial (e.g., GP2-PCB-9901)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF2C415E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF1E3A8A))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: const BorderSide(color: Color(0xFF10B981))),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton(
                onPressed: () async {
                  final serial = _newGP6SerialCtrl.text.trim();
                  if (serial.isEmpty) return;
                  final list = List<String>.from(_adminRules['gp6_serials'] as List<dynamic>? ?? []);
                  if (!list.contains(serial)) {
                    list.add(serial);
                    _adminRules['gp6_serials'] = list;
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newGP6SerialCtrl.clear();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
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
            items: gp6List.map((sn) {
              final rounds = _storageService.calculateAssetRounds(allRecords, sn);
              return {
                'label': sn,
                'serial': sn,
                'rounds': rounds,
                'category': 'GP2 (Port)',
              };
            }).toList(),
            accentColor: const Color(0xFF10B981),
            onDelete: (item) async {
              gp6List.remove(item['serial']);
              _adminRules['gp6_serials'] = gp6List;
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
          const SizedBox(height: 18.0),

          // 3. EPVAT BARREL TEST SERIALS
          _buildAssetCategoryHeader('EPVAT Barrel Test Serial Numbers', Icons.adjust_rounded, const Color(0xFF06B6D4)),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newEpvatBarrelCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'JetBrainsMono'),
                  decoration: InputDecoration(
                    hintText: 'EPVAT Barrel Serial (e.g., EPVAT-B-201)',
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
                  final list = List<String>.from(_adminRules['epvat_barrels'] as List<dynamic>? ?? []);
                  if (!list.contains(serial)) {
                    list.add(serial);
                    _adminRules['epvat_barrels'] = list;
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newEpvatBarrelCtrl.clear();
                    });
                  }
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
            items: epvatBarrels.map((sn) {
              final rounds = _storageService.calculateAssetRounds(allRecords, sn);
              return {
                'label': sn,
                'serial': sn,
                'rounds': rounds,
                'category': 'EPVAT Barrel',
              };
            }).toList(),
            accentColor: const Color(0xFF06B6D4),
            onDelete: (item) async {
              epvatBarrels.remove(item['serial']);
              _adminRules['epvat_barrels'] = epvatBarrels;
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
          const SizedBox(height: 18.0),

          // 4. ACCURACY BARREL TEST SERIALS
          _buildAssetCategoryHeader('Accuracy Barrel Test Serial Numbers', Icons.radar_rounded, const Color(0xFFF59E0B)),
          const SizedBox(height: 8.0),
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
                  final list = List<String>.from(_adminRules['accuracy_barrels'] as List<dynamic>? ?? []);
                  if (!list.contains(serial)) {
                    list.add(serial);
                    _adminRules['accuracy_barrels'] = list;
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newAccuracyBarrelCtrl.clear();
                    });
                  }
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
            items: accBarrels.map((sn) {
              final rounds = _storageService.calculateAssetRounds(allRecords, sn);
              return {
                'label': sn,
                'serial': sn,
                'rounds': rounds,
                'category': 'Accuracy Barrel',
              };
            }).toList(),
            accentColor: const Color(0xFFF59E0B),
            onDelete: (item) async {
              accBarrels.remove(item['serial']);
              _adminRules['accuracy_barrels'] = accBarrels;
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
          const SizedBox(height: 18.0),

          // 5. PRIMER SUPPLIERS
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

          // 6. PROPELLANT SUPPLIERS
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
              propellantSuppliers.remove(item['serial']);
              _adminRules['propellant_suppliers'] = propellantSuppliers;
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
          const SizedBox(height: 18.0),

          // 7. PROPELLANT CODES
          _buildAssetCategoryHeader('Propellant Codes (Component Test)', Icons.qr_code_rounded, const Color(0xFFA855F7)),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
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
                    await _storageService.saveRules(_adminRules);
                    setState(() {
                      _adminRules = Map<String, dynamic>.from(_adminRules);
                      _newPropellantCodeCtrl.clear();
                    });
                  }
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
            items: propellantCodes.map((s) => {'label': s, 'serial': s, 'rounds': 0, 'category': 'Propellant Code'}).toList(),
            accentColor: const Color(0xFFA855F7),
            onDelete: (item) async {
              propellantCodes.remove(item['serial']);
              _adminRules['propellant_codes'] = propellantCodes;
              await _storageService.saveRules(_adminRules);
              setState(() => _adminRules = Map<String, dynamic>.from(_adminRules));
            },
          ),
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
          Text(label, style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 12.5)),
          Text(val, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12.5, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRulesManagementCard(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evaluation Rules & Requirements',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8.0),
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
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            ),
          ),
          const SizedBox(height: 12.0),

          // Caliber selector for tests that have caliber-specific specifications
          Builder(builder: (context) {
            final bool isCaliberAware = _selectedRuleTest != 'Firing Rate Cycle Test' &&
                _selectedRuleTest != 'Barrel Serial Numbers' &&
                _selectedRuleTest != 'Barrels' &&
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
            Text('Configure Temperature Specifications for $_ruleSelectedCaliber', style: const TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6.0),
            Row(
              children: ['+21', '+52', '-54'].map((temp) {
                final isSel = _ruleSelectedEpvatTemp == temp;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text('$temp °C', style: TextStyle(color: isSel ? Colors.white : const Color(0xFF8E96A3), fontSize: 12.0)),
                    selected: isSel,
                    selectedColor: const Color(0xFF06B6D4),
                    backgroundColor: Colors.black.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _ruleSelectedEpvatTemp = temp;
                        });
                        _syncRulesControllers();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16.0),
            _buildRuleTextField('Min Velocity for $_ruleSelectedCaliber at $_ruleSelectedEpvatTemp °C (m/s)', _ruleEpvMinVelCtrl),
            _buildRuleTextField('Max Velocity for $_ruleSelectedCaliber at $_ruleSelectedEpvatTemp °C (m/s)', _ruleEpvMaxVelCtrl),
            _buildRuleTextField('Max P1 Chamber Pressure for $_ruleSelectedCaliber (bar)', _ruleEpvMaxP1Ctrl),
            _buildRuleTextField('Min P2 Port Pressure for $_ruleSelectedCaliber (bar)', _ruleEpvMinP2Ctrl),
            _buildRuleTextField('Max Action Time for $_ruleSelectedCaliber at $_ruleSelectedEpvatTemp °C (ms)', _ruleEpvMaxActionTimeCtrl),
            _buildRuleTextField('Evaluation Instructions Remarks for $_ruleSelectedCaliber', _ruleEpvInstructionsCtrl, isMultiline: true),
            const SizedBox(height: 4.0),
            const Divider(color: Color(0xFF1F293D)),
            const SizedBox(height: 8.0),

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

            const Divider(color: Color(0xFF1F293D)),
            const SizedBox(height: 8.0),

            // --- Extended Sentencing Flags ---
            const Text(
              'EXTENDED SENTENCING RULES',
              style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 1.0),
            ),
            const SizedBox(height: 8.0),
            // 3-Sigma Pressure Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Enable 3-Sigma Pressure Reject', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2.0),
                        Text('Auto-reject if P1 Mean + 3×SD exceeds limit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _ruleEpvThreeSigmaEnabled,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => setState(() => _ruleEpvThreeSigmaEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
            // Temp Velocity Delta Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Enable Temp Velocity Delta Check', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2.0),
                        Text('Reject if V(+52°C) − V(−54°C) > Max Delta', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _ruleEpvTempDeltaEnabled,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => setState(() => _ruleEpvTempDeltaEnabled = val),
                  ),
                ],
              ),
            ),
            if (_ruleEpvTempDeltaEnabled) ...[
              const SizedBox(height: 10.0),
              _buildRuleTextField('Max Allowed Velocity Delta V(+21°C) − V(+52°C) (m/s)', _ruleEpvTempDeltaMaxCtrl),
            ],
            
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
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets toolbar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            newMap[_ruleSelectedCaliber] = EpvatFormulaHelper.getDefaultFormulas();
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Standard EPVAT formulas added for selected caliber.')),
                          );
                        },
                        icon: const Icon(Icons.playlist_add_check, size: 14),
                        label: const Text('Load Standard Presets', style: TextStyle(fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('P1 Mean + 3SD (+21°C)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                            curList.add({
                              'name': 'P1 3-Sigma (+21°C)',
                              'formula': 'P1 Mean @ 21 + 3 * P1 SD @ 21',
                              'operator': '<=',
                              'limit': '3800',
                              'unit': 'bar',
                            });
                            newMap[_ruleSelectedCaliber] = curList;
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('P1 Delta (|21°C - 52°C|)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                            curList.add({
                              'name': 'P1 Difference (+21°C vs +52°C)',
                              'formula': 'abs(P1 Mean @ 21 - P1 Mean @ 52)',
                              'operator': '<=',
                              'limit': '450',
                              'unit': 'bar',
                            });
                            newMap[_ruleSelectedCaliber] = curList;
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Velocity Delta (|21°C - 52°C|)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                            curList.add({
                              'name': 'Velocity Delta (+21°C vs +52°C)',
                              'formula': 'abs(Vel Mean @ 21 - Vel Mean @ 52)',
                              'operator': '<=',
                              'limit': '30',
                              'unit': 'm/s',
                            });
                            newMap[_ruleSelectedCaliber] = curList;
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Velocity Delta (±30 m/s)', style: TextStyle(fontSize: 11.0, color: Colors.white)),
                        backgroundColor: const Color(0xFF2C415E),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            final curList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                            curList.add({
                              'name': 'Velocity Tolerance (+21°C vs +52°C)',
                              'formula': 'abs(Vel Mean @ 21 - Vel Mean @ 52)',
                              'operator': '±',
                              'limit': '30',
                              'unit': 'm/s',
                            });
                            newMap[_ruleSelectedCaliber] = curList;
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14.0),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No custom sentencing calculations defined for this caliber. Click "Load Standard Presets" or "+ Add Formula" below.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 12.0, fontStyle: FontStyle.italic)),
                    )
                  else ...[
                    Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Rule / Check Name', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text('Adjustable Formula Expression', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Operator', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Limit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Unit', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.0, fontWeight: FontWeight.bold))),
                        SizedBox(width: 32),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E3A8A), height: 14),
                    ...List.generate(list.length, (i) {
                      final item = Map<String, dynamic>.from(list[i] as Map);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: item['name'] ?? '',
                                key: ValueKey('name_${_ruleSelectedCaliber}_$i'),
                                style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                decoration: _getFormulaFieldDecoration(),
                                onChanged: (val) {
                                  final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                  final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                  final innerMap = Map<String, dynamic>.from(newList[i] as Map);
                                  innerMap['name'] = val;
                                  newList[i] = innerMap;
                                  newMap[_ruleSelectedCaliber] = newList;
                                  _adminRules['epvat']?['custom_formulas'] = newMap;
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                initialValue: item['formula'] ?? '',
                                key: ValueKey('formula_${_ruleSelectedCaliber}_$i'),
                                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                                decoration: _getFormulaFieldDecoration(),
                                onChanged: (val) {
                                  final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                  final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                  final innerMap = Map<String, dynamic>.from(newList[i] as Map);
                                  innerMap['formula'] = val;
                                  newList[i] = innerMap;
                                  newMap[_ruleSelectedCaliber] = newList;
                                  _adminRules['epvat']?['custom_formulas'] = newMap;
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C415E),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(color: const Color(0xFF1E3A8A)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: (['<=', '>=', '<', '>', '==', '±'].contains(item['operator']))
                                        ? item['operator']
                                        : (item['operator'] == '+/-' ? '±' : '<='),
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF344D6E),
                                    style: const TextStyle(color: Colors.white, fontSize: 12.0),
                                    onChanged: (val) {
                                      setState(() {
                                        final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                        final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                        final innerMap = Map<String, dynamic>.from(newList[i] as Map);
                                        innerMap['operator'] = val;
                                        newList[i] = innerMap;
                                        newMap[_ruleSelectedCaliber] = newList;
                                        _adminRules['epvat']?['custom_formulas'] = newMap;
                                      });
                                    },
                                    items: ['<=', '>=', '<', '>', '==', '±'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: item['limit'] ?? '',
                                key: ValueKey('limit_${_ruleSelectedCaliber}_$i'),
                                style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono'),
                                decoration: _getFormulaFieldDecoration(),
                                onChanged: (val) {
                                  final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                  final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                  final innerMap = Map<String, dynamic>.from(newList[i] as Map);
                                  innerMap['limit'] = val;
                                  newList[i] = innerMap;
                                  newMap[_ruleSelectedCaliber] = newList;
                                  _adminRules['epvat']?['custom_formulas'] = newMap;
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: item['unit'] ?? (item['formula'].toString().toLowerCase().contains('vel') ? 'm/s' : 'bar'),
                                key: ValueKey('unit_${_ruleSelectedCaliber}_$i'),
                                style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11.0, fontFamily: 'JetBrainsMono'),
                                decoration: _getFormulaFieldDecoration(),
                                onChanged: (val) {
                                  final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                  final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                  final innerMap = Map<String, dynamic>.from(newList[i] as Map);
                                  innerMap['unit'] = val;
                                  newList[i] = innerMap;
                                  newMap[_ruleSelectedCaliber] = newList;
                                  _adminRules['epvat']?['custom_formulas'] = newMap;
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                                  final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                                  newList.removeAt(i);
                                  newMap[_ruleSelectedCaliber] = newList;
                                  _adminRules['epvat']?['custom_formulas'] = newMap;
                                });
                              },
                              child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            final newMap = Map<String, dynamic>.from(_adminRules['epvat']?['custom_formulas'] ?? {});
                            final newList = List<dynamic>.from(newMap[_ruleSelectedCaliber] ?? []);
                            newList.add({'name': 'Custom check', 'formula': 'P1 Mean @ 21 + 3 * P1 SD @ 21', 'operator': '<=', 'limit': '3800', 'unit': 'bar'});
                            newMap[_ruleSelectedCaliber] = newList;
                            _adminRules['epvat']?['custom_formulas'] = newMap;
                          });
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Formula', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF06B6D4),
                          side: const BorderSide(color: Color(0xFF06B6D4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
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
                                  onChanged: (val) {
                                    setState(() {
                                      final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                                      final map = Map<String, dynamic>.from(list[i] as Map);
                                      map['type'] = val;
                                      list[i] = map;
                                      _adminRules['cyclic_rate'] = {'weapons': list};
                                    });
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
                            onTap: () {
                              setState(() {
                                final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                                list.removeAt(i);
                                _adminRules['cyclic_rate'] = {'weapons': list};
                              });
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
                      onPressed: () {
                        setState(() {
                          final list = List<dynamic>.from(_adminRules['cyclic_rate']?['weapons'] ?? []);
                          list.add({'name': 'New Weapon', 'type': 'Rifle', 'min': 550, 'max': 920});
                          _adminRules['cyclic_rate'] = {'weapons': list};
                        });
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
          ] else if (_selectedRuleTest == 'GP Transducers (GP1 & GP2)') ...[
            const Text(
              'Manage authorized GP Transducers for EPVAT testing (GP1 Chamber Transducer & GP2 Gas Port Transducer). Operators will select from these sensors during EPVAT ballistic inspections.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E96A3), height: 1.4),
            ),
            const SizedBox(height: 16.0),
            
            // Selector for GP1 vs GP2
            Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _ruleSelectedGPType = 'GP1'),
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: _ruleSelectedGPType == 'GP1' ? const Color(0xFF06B6D4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensors, size: 16, color: _ruleSelectedGPType == 'GP1' ? Colors.white : const Color(0xFF8E96A3)),
                            const SizedBox(width: 8),
                            Text(
                              'GP1 (Chamber / P1)',
                              style: TextStyle(
                                color: _ruleSelectedGPType == 'GP1' ? Colors.white : const Color(0xFF8E96A3),
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _ruleSelectedGPType = 'GP2'),
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: _ruleSelectedGPType == 'GP2' ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensors, size: 16, color: _ruleSelectedGPType == 'GP2' ? Colors.white : const Color(0xFF8E96A3)),
                            const SizedBox(width: 8),
                            Text(
                              'GP2 (Gas Port / P2)',
                              style: TextStyle(
                                color: _ruleSelectedGPType == 'GP2' ? Colors.white : const Color(0xFF8E96A3),
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ruleNewGPTransducerCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13.0, fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: _ruleSelectedGPType == 'GP1'
                          ? 'Enter GP1 Model / S.N. (e.g., GP1-005, PCB 119B SN#4120)'
                          : 'Enter GP2 Model / S.N. (e.g., GP2-005, PCB 119B SN#4121)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12.0),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: _ruleSelectedGPType == 'GP1' ? const Color(0xFF06B6D4) : const Color(0xFF6366F1))),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: () {
                    final text = _ruleNewGPTransducerCtrl.text.trim();
                    if (text.isNotEmpty) {
                      final gpMap = Map<String, dynamic>.from(_adminRules['gp_transducers'] ?? {});
                      final key = _ruleSelectedGPType.toLowerCase();
                      final list = List<String>.from(gpMap[key] ?? []);
                      if (!list.contains(text)) {
                        list.add(text);
                        gpMap[key] = list;
                        setState(() {
                          _adminRules['gp_transducers'] = gpMap;
                          _ruleNewGPTransducerCtrl.clear();
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Add $_ruleSelectedGPType'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ruleSelectedGPType == 'GP1' ? const Color(0xFF06B6D4) : const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Side-by-side registered lists
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GP1 List
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.speed, size: 14, color: Color(0xFF06B6D4)),
                          SizedBox(width: 6),
                          Text('Registered GP1 Transducers (P1):', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Builder(builder: (context) {
                        final gpMap = _adminRules['gp_transducers'] ?? {};
                        final list = List<String>.from(gpMap['gp1'] ?? []);
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No GP1 transducers registered.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic)),
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
                              final name = list[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono')),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        final updatedGp = Map<String, dynamic>.from(_adminRules['gp_transducers'] ?? {});
                                        final updated = List<String>.from(updatedGp['gp1'] ?? []);
                                        updated.removeAt(idx);
                                        updatedGp['gp1'] = updated;
                                        setState(() {
                                          _adminRules['gp_transducers'] = updatedGp;
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
                    ],
                  ),
                ),
                const SizedBox(width: 14.0),
                // GP2 List
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.speed, size: 14, color: Color(0xFF6366F1)),
                          SizedBox(width: 6),
                          Text('Registered GP2 Transducers (P2):', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Builder(builder: (context) {
                        final gpMap = _adminRules['gp_transducers'] ?? {};
                        final list = List<String>.from(gpMap['gp2'] ?? []);
                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No GP2 transducers registered.', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 11.5, fontStyle: FontStyle.italic)),
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
                              final name = list[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12.0, fontFamily: 'JetBrainsMono')),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        final updatedGp = Map<String, dynamic>.from(_adminRules['gp_transducers'] ?? {});
                                        final updated = List<String>.from(updatedGp['gp2'] ?? []);
                                        updated.removeAt(idx);
                                        updatedGp['gp2'] = updated;
                                        setState(() {
                                          _adminRules['gp_transducers'] = updatedGp;
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
                    ],
                  ),
                ),
              ],
            ),
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
                  onPressed: () {
                    final sn = _ruleNewBarrelSNCtrl.text.trim();
                    if (sn.isNotEmpty) {
                      final list = List<String>.from(_adminRules['barrel_serial_numbers'] ?? []);
                      if (!list.contains(sn)) {
                        list.add(sn);
                        setState(() {
                          _adminRules['barrel_serial_numbers'] = list;
                          _ruleNewBarrelSNCtrl.clear();
                        });
                      }
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
                            onPressed: () {
                              final updated = List<String>.from(_adminRules['barrel_serial_numbers'] ?? []);
                              updated.removeAt(idx);
                              setState(() {
                                _adminRules['barrel_serial_numbers'] = updated;
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
                        onPressed: () {
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
                            onPressed: () {
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

                              setState(() {
                                _adminRules['function_test'] = updatedFunc;
                                _adminRules['cyclic_rate'] = updatedCyclic;
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

            _buildFunctionLevelConfigCard(
              title: 'Level 1: Critical Defect',
              badgeColor: const Color(0xFFEF4444),
              maxLimitCtrl: _ruleFuncL1MaxCtrl,
              descCtrl: _ruleFuncL1DescCtrl,
              ruleNote: 'Exceeding threshold results in automatic REJECTED status.',
            ),
            const SizedBox(height: 12.0),

            _buildFunctionLevelConfigCard(
              title: 'Level 2: Major Defect',
              badgeColor: const Color(0xFFF97316),
              maxLimitCtrl: _ruleFuncL2MaxCtrl,
              descCtrl: _ruleFuncL2DescCtrl,
              ruleNote: 'Exceeding threshold results in automatic REJECTED status.',
            ),
            const SizedBox(height: 12.0),

            _buildFunctionLevelConfigCard(
              title: 'Level 3: Minor Defect',
              badgeColor: const Color(0xFFFBBF24),
              maxLimitCtrl: _ruleFuncL3MaxCtrl,
              descCtrl: _ruleFuncL3DescCtrl,
              ruleNote: 'Exceeding threshold triggers RETEST status.',
            ),
            const SizedBox(height: 12.0),

            _buildFunctionLevelConfigCard(
              title: 'Level 4: Level 4 Defect',
              badgeColor: const Color(0xFF38BDF8),
              maxLimitCtrl: _ruleFuncL4MaxCtrl,
              descCtrl: _ruleFuncL4DescCtrl,
              ruleNote: 'Exceeding threshold triggers RETEST status.',
            ),
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
                  onPressed: () {
                    final wpName = _ruleNewFuncWeaponCtrl.text.trim();
                    if (wpName.isNotEmpty) {
                      final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                      final list = List<String>.from(func['weapons'] ?? []);
                      if (!list.contains(wpName)) {
                        list.add(wpName);
                        func['weapons'] = list;
                        setState(() {
                          _adminRules['function_test'] = func;
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
                            onPressed: () {
                              final func = Map<String, dynamic>.from(_adminRules['function_test'] ?? {});
                              final updated = List<String>.from(func['weapons'] ?? []);
                              updated.removeAt(idx);
                              func['weapons'] = updated;
                              setState(() {
                                _adminRules['function_test'] = func;
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
      ),
    );
  }

  Widget _buildFunctionLevelConfigCard({
    required String title,
    required Color badgeColor,
    required TextEditingController maxLimitCtrl,
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
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Allowed Defects', style: TextStyle(color: Color(0xFF8E96A3), fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    TextField(
                      controller: maxLimitCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: badgeColor, fontSize: 13.0, fontWeight: FontWeight.bold, fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: badgeColor)),
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
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'e.g., Blown primer, Split case, Perforated primer...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide(color: badgeColor)),
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
      },
    );
  }

  InputDecoration _getFormulaFieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
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
      mainContent = _buildModulePlaceholder('Equipment Report', Icons.construction_outlined, const Color(0xFFF59E0B));
    } else if (_currentModule == 'Executive Reports') {
      mainContent = ExecutiveReportsTab(
        lotAcceptanceRecords: _records,
        dailyTestRecords: _dailyTestRecords,
        componentTestRecords: _componentTestRecords,
        base64Logo: _base64Logo,
        loggedInUser: _currentUserEmail.isNotEmpty ? _currentUserEmail : 'Operator',
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
                              'v1.4.3',
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
                    color: const Color(0xFF263852),
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
        color: const Color(0xFF344D6E),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF1E3A8A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
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
                        color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                      label: Text(
                        subTabs[index]['label'],
                        style: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        backgroundColor: isActive ? const Color(0xFF0284C7).withOpacity(0.25) : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          side: BorderSide(
                            color: isActive ? const Color(0xFF38BDF8) : Colors.transparent,
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

          // Header Badges: Welcome Greeting (Instruction 18), Live Ticking Digital Clock (Instruction 19), Alerts Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instruction 18: Welcome greeting with user's name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C415E),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF1E3A8A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👋', style: TextStyle(fontSize: 12.0)),
                    const SizedBox(width: 6.0),
                    Text(
                      'Welcome, ${_currentUserEmail.isNotEmpty ? _currentUserEmail : 'User'}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // Instruction 19: Live ticking digital clock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C415E),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: const Color(0xFF1E3A8A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14.0, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6.0),
                    Text(
                      _formatLiveClock(_currentTime),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: Color(0xFF38BDF8),
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
                      backgroundColor: const Color(0xFF344D6E),
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
                    color: _submissionAlertsEnabled ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF2C415E),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: _submissionAlertsEnabled ? const Color(0xFF10B981) : const Color(0xFF1E3A8A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _submissionAlertsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        size: 15.0,
                        color: _submissionAlertsEnabled ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        _submissionAlertsEnabled ? 'Alerts: ON' : 'Alerts: OFF',
                        style: TextStyle(
                          color: _submissionAlertsEnabled ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
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
          color: const Color(0xFF344D6E),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFF1E3A8A)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
              blurRadius: 20.0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 48.0),
            ),
            const SizedBox(height: 24.0),
            Text(
              name.toUpperCase(),
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Module Initialized',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 16.0),
            const Text(
              'This laboratory workspace has been initialized successfully. The underlying database schemas and platform hooks are ready.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), height: 1.5),
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
