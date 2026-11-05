/// Resolves existing activity by user ID without changing historical records.
String activityActorName(
  Map<String, dynamic> event,
  Map<String, Map<String, dynamic>> users,
) {
  final name = users[event['userId']]?['name'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  return 'Usuario no disponible';
}
