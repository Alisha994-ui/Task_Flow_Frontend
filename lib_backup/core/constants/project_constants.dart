import 'package:flutter/material.dart';

/// Single place where backend choice values live.
///
/// IMPORTANT: these strings must match the `choices` defined on your Django
/// models (Project.status, Project.priority, User.role). If the backend uses
/// different values, change them here only - the whole admin panel reads
/// from this file.
class ProjectStatus {
  const ProjectStatus._();

  static const String planning = 'PLANNING';
  static const String active = 'ACTIVE';
  static const String onHold = 'ON_HOLD';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';

  static const List<String> all = <String>[
    planning,
    active,
    onHold,
    completed,
    cancelled,
  ];

  static String label(String value) => humanizeChoice(value);

  static Color color(String value) {
    switch (value) {
      case planning:
        return const Color(0xFF6366F1);
      case active:
        return const Color(0xFF2563EB);
      case onHold:
        return const Color(0xFFD97706);
      case completed:
        return const Color(0xFF059669);
      case cancelled:
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class ProjectPriority {
  const ProjectPriority._();

  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String urgent = 'URGENT';

  static const List<String> all = <String>[low, medium, high, urgent];

  static String label(String value) => humanizeChoice(value);

  static Color color(String value) {
    switch (value) {
      case low:
        return const Color(0xFF0D9488);
      case medium:
        return const Color(0xFF2563EB);
      case high:
        return const Color(0xFFEA580C);
      case urgent:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class UserRoles {
  const UserRoles._();

  static const String admin = 'ADMIN';
  static const String projectManager = 'PROJECT_MANAGER';
  static const String teamLead = 'TEAM_LEAD';
  static const String employee = 'EMPLOYEE';
  static const String viewer = 'VIEWER';

  static const List<String> all = <String>[
    admin,
    projectManager,
    teamLead,
    employee,
    viewer,
  ];

  /// Roles that can actually be picked when creating or editing a user.
  /// The server's own role choices do not include Viewer - offering it
  /// here only produces "role: VIEWER is not a valid choice" on save,
  /// so it is left out until the two sides agree on it.
  static const List<String> assignable = <String>[
    admin,
    projectManager,
    teamLead,
    employee,
  ];

  static String label(String value) => humanizeChoice(value);

  static Color color(String value) {
    switch (value) {
      case admin:
        return const Color(0xFF7C3AED);
      case projectManager:
        return const Color(0xFF2563EB);
      case teamLead:
        return const Color(0xFF0D9488);
      case employee:
        return const Color(0xFF4B5563);
      case viewer:
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

/// Turns `IN_PROGRESS` into `In progress` so raw backend values never reach
/// the screen.
String humanizeChoice(String value) {
  if (value.trim().isEmpty) {
    return '-';
  }

  final String cleaned = value.replaceAll('_', ' ').toLowerCase().trim();

  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

/// Sentinel used by the filter dropdowns.
const String kFilterAll = 'ALL';
