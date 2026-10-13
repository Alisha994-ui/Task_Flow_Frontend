class AdminDashboardModel {
  final int totalUsers;
  final int activeUsers;
  final int totalProjects;
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int inProgressTasks;
  final int overdueTasks;

  AdminDashboardModel({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalProjects,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.overdueTasks,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      totalProjects: json['total_projects'] ?? 0,
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      pendingTasks: json['pending_tasks'] ?? 0,
      inProgressTasks: json['in_progress_tasks'] ?? 0,
      overdueTasks: json['overdue_tasks'] ?? 0,
    );
  }
}
