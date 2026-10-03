import 'package:flutter/material.dart';

import 'project_constants.dart';

/// Mirrors `Task.Status` in the Django model.
class TaskStatus {
  const TaskStatus._();

  static const String todo = 'TODO';
  static const String inProgress = 'IN_PROGRESS';
  static const String inReview = 'IN_REVIEW';
  static const String completed = 'COMPLETED';
  static const String blocked = 'BLOCKED';
  static const String onHold = 'ON_HOLD';

  static const List<String> all = <String>[
    todo,
    inProgress,
    inReview,
    completed,
    blocked,
    onHold,
  ];

  /// Statuses that mean the task no longer needs work.
  static const Set<String> closed = <String>{completed};

  static String label(String value) {
    switch (value) {
      case todo:
        return 'To do';
      case inProgress:
        return 'In progress';
      case inReview:
        return 'In review';
      case completed:
        return 'Completed';
      case blocked:
        return 'Blocked';
      case onHold:
        return 'On hold';
      default:
        return humanizeChoice(value);
    }
  }

  static Color color(String value) {
    switch (value) {
      case todo:
        return const Color(0xFF6B7280);
      case inProgress:
        return const Color(0xFF2563EB);
      case inReview:
        return const Color(0xFF7C3AED);
      case completed:
        return const Color(0xFF059669);
      case blocked:
        return const Color(0xFFDC2626);
      case onHold:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static IconData icon(String value) {
    switch (value) {
      case todo:
        return Icons.radio_button_unchecked;
      case inProgress:
        return Icons.timelapse;
      case inReview:
        return Icons.rate_review_outlined;
      case completed:
        return Icons.check_circle;
      case blocked:
        return Icons.block;
      case onHold:
        return Icons.pause_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }
}

/// Mirrors `Task.Priority` - same values as the project priority.
class TaskPriority {
  const TaskPriority._();

  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String urgent = 'URGENT';

  static const List<String> all = <String>[low, medium, high, urgent];

  static String label(String value) => ProjectPriority.label(value);

  static Color color(String value) => ProjectPriority.color(value);
}

/// Action strings the backend writes into ActivityLog.
class ActivityAction {
  const ActivityAction._();

  static const String taskCreated = 'TASK_CREATED';
  static const String statusChanged = 'STATUS_CHANGED';
  static const String taskReassigned = 'TASK_REASSIGNED';
  static const String commentAdded = 'COMMENT_ADDED';
  static const String attachmentAdded = 'ATTACHMENT_ADDED';
  static const String timeLogged = 'TIME_LOGGED';

  static String label(String value) => humanizeChoice(value);

  static IconData icon(String value) {
    switch (value) {
      case taskCreated:
        return Icons.add_task;
      case statusChanged:
        return Icons.swap_horiz;
      case taskReassigned:
        return Icons.person_outline;
      case commentAdded:
        return Icons.chat_bubble_outline;
      case attachmentAdded:
        return Icons.attach_file;
      case timeLogged:
        return Icons.timer_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  static Color color(String value) {
    switch (value) {
      case taskCreated:
        return const Color(0xFF2563EB);
      case statusChanged:
        return const Color(0xFF7C3AED);
      case taskReassigned:
        return const Color(0xFF0D9488);
      case commentAdded:
        return const Color(0xFFD97706);
      case attachmentAdded:
        return const Color(0xFF6B7280);
      case timeLogged:
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
