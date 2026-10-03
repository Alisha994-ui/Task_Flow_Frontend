import '../../models/project_model.dart';
import '../constants/project_constants.dart';

/// A project stops accepting work once it is finished, cancelled or
/// archived. Managers and leads see it, but cannot change it.
///
/// Admins are deliberately not covered by this - reopening a project or
/// fixing a mistake on a closed one has to stay possible somewhere.
bool isProjectClosed(ProjectModel? project) {
  if (project == null) {
    return false;
  }

  return project.isArchived ||
      project.status == ProjectStatus.completed ||
      project.status == ProjectStatus.cancelled;
}

/// Short reason to show the person when something is blocked.
String projectLockReason(ProjectModel? project) {
  if (project == null) {
    return 'This project is closed.';
  }

  if (project.isArchived) {
    return '"${project.name}" is archived, so its tasks are read-only.';
  }

  if (project.status == ProjectStatus.cancelled) {
    return '"${project.name}" was cancelled, so its tasks are read-only.';
  }

  return '"${project.name}" is complete, so its tasks are read-only.';
}
