import '../constants/project_constants.dart';

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// `12 Mar 2026` - for display only.
String formatDate(DateTime? date, {String fallback = 'Not set'}) {
  if (date == null) {
    return fallback;
  }

  final DateTime local = date.toLocal();

  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// `2026-03-12` - the format the Django API expects for a DateField.
String apiDate(DateTime date) {
  return '${date.year}-${_two(date.month)}-${_two(date.day)}';
}

/// Null-safe wrapper so form state can be passed straight to the service.
String? apiDateOrNull(DateTime? date) {
  if (date == null) {
    return null;
  }

  return apiDate(date);
}

/// Parses an API date string (`2026-03-12` or a full ISO timestamp).
DateTime? parseApiDate(dynamic value) {
  if (value == null) {
    return null;
  }

  final String raw = value.toString().trim();

  if (raw.isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}

/// Statuses that mean the work is closed, so an end date in the past is fine.
const Set<String> _closedStatuses = <String>{
  ProjectStatus.completed,
  ProjectStatus.cancelled,
};

/// True when the project should have finished already but is still open.
bool isOverdue(DateTime? endDate, String status) {
  if (endDate == null) {
    return false;
  }

  if (_closedStatuses.contains(status)) {
    return false;
  }

  final DateTime local = endDate.toLocal();

  // Compare against the end of the due day so a project is not flagged
  // overdue on the day it is actually due.
  final DateTime endOfDueDay = DateTime(
    local.year,
    local.month,
    local.day,
    23,
    59,
    59,
  );

  return DateTime.now().isAfter(endOfDueDay);
}

/// Whole days left until the due date. Negative means days overdue,
/// null means no due date is set.
int? daysUntil(DateTime? endDate) {
  if (endDate == null) {
    return null;
  }

  final DateTime local = endDate.toLocal();
  final DateTime due = DateTime(local.year, local.month, local.day);
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);

  return due.difference(today).inDays;
}

/// Short human label for a due date: `Due today`, `3 days left`,
/// `2 days overdue`.
String dueLabel(DateTime? endDate, {String fallback = 'No due date'}) {
  final int? days = daysUntil(endDate);

  if (days == null) {
    return fallback;
  }

  if (days == 0) {
    return 'Due today';
  }

  if (days > 0) {
    return days == 1 ? '1 day left' : '$days days left';
  }

  final int overdue = days.abs();

  return overdue == 1 ? '1 day overdue' : '$overdue days overdue';
}

/// `3d 4h`, `4h 20m`, `25m` - the shape of a span, not a timestamp.
String formatSpan(Duration span) {
  if (span.inMinutes < 1) {
    return 'under a minute';
  }

  if (span.inMinutes < 60) {
    return '${span.inMinutes}m';
  }

  if (span.inHours < 24) {
    final int minutes = span.inMinutes % 60;

    return minutes == 0 ? '${span.inHours}h' : '${span.inHours}h ${minutes}m';
  }

  final int days = span.inDays;
  final int hours = span.inHours % 24;

  return hours == 0 ? '${days}d' : '${days}d ${hours}h';
}

/// How long something took from [start] to [end]. Null when either end
/// is missing or the dates make no sense.
String? completionSpan(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return null;
  }

  final Duration span = end.difference(start);

  if (span.isNegative) {
    return null;
  }

  return formatSpan(span);
}
