class TaskModel {
  final String id;
  final String title;
  final bool completed;
  final DateTime? dueDate;
  final String priority;

  const TaskModel({
    required this.id,
    required this.title,
    required this.completed,
    this.dueDate,
    required this.priority,
  });

  /// Create a TaskModel from Firestore data
  factory TaskModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TaskModel(
      id: id,
      title: data['title']?.toString() ?? '',
      completed: data['completed'] == true,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as dynamic).toDate()
          : null,
      priority: data['priority']?.toString() ?? 'Medium',
    );
  }

  /// Convert the task to a Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'completed': completed,
      'dueDate': dueDate,
      'priority': priority,
    };
  }

  /// Create a copy with selected fields changed
  TaskModel copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? dueDate,
    String? priority,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
    );
  }
}