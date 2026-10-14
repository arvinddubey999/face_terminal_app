class TaskReplyModel {
  final int id;
  final int userId;
  final String userName;
  final String? userPhoto;
  final String message;
  final String? attachmentUrl;
  final String? createdAt;

  TaskReplyModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.message,
    this.attachmentUrl,
    this.createdAt,
  });

  factory TaskReplyModel.fromJson(Map<String, dynamic> json) {
    return TaskReplyModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'User',
      userPhoto: json['user_photo'],
      message: json['message'] ?? '',
      attachmentUrl: json['attachment_url'],
      createdAt: json['created_at'],
    );
  }
}

class TaskHistoryModel {
  final int id;
  final String userName;
  final String action;
  final String? details;
  final String? createdAt;

  TaskHistoryModel({
    required this.id,
    required this.userName,
    required this.action,
    this.details,
    this.createdAt,
  });

  factory TaskHistoryModel.fromJson(Map<String, dynamic> json) {
    return TaskHistoryModel(
      id: json['id'] ?? 0,
      userName: json['user_name'] ?? 'System',
      action: json['action'] ?? '',
      details: json['details'],
      createdAt: json['created_at'],
    );
  }
}

class TaskModel {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String repeatType;
  final String? dueDate;
  final String? dueTime;
  final String? client;
  final int? departmentId;
  final String? department;
  final int? assignedToId;
  final String? assignedToName;
  final int? createdBy;
  final String? createdByName;
  final String? attachmentUrl;
  final int repliesCount;
  final List<TaskReplyModel> replies;
  final List<TaskHistoryModel> histories;
  final List<dynamic> assignees;
  final List<dynamic> others;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.repeatType = 'none',
    this.dueDate,
    this.dueTime,
    this.client,
    this.departmentId,
    this.department,
    this.assignedToId,
    this.assignedToName,
    this.createdBy,
    this.createdByName,
    this.attachmentUrl,
    this.repliesCount = 0,
    this.replies = const [],
    this.histories = const [],
    this.assignees = const [],
    this.others = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    var rawReplies = json['replies'] as List? ?? [];
    List<TaskReplyModel> parsedReplies = rawReplies.map((x) => TaskReplyModel.fromJson(x)).toList();

    var rawHistories = json['histories'] as List? ?? [];
    List<TaskHistoryModel> parsedHistories = rawHistories.map((x) => TaskHistoryModel.fromJson(x)).toList();

    return TaskModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      repeatType: json['repeat_type'] ?? 'none',
      dueDate: json['due_date'],
      dueTime: json['due_time'],
      client: json['client'],
      departmentId: json['department_id'],
      department: json['department'],
      assignedToId: json['assigned_to_id'],
      assignedToName: json['assigned_to_name'],
      createdBy: json['created_by'],
      createdByName: json['created_by_name'],
      attachmentUrl: json['attachment_url'],
      repliesCount: json['replies_count'] ?? parsedReplies.length,
      replies: parsedReplies,
      histories: parsedHistories,
      assignees: json['assignees'] as List? ?? [],
      others: json['others'] as List? ?? [],
    );
  }

  String? get assigneeName => assignedToName;
}
