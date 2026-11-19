class TaskAttachmentModel {
  final int id;
  final String fileName;
  final String filePath;
  final String fileUrl;
  final int? userId;
  final String? userName;

  TaskAttachmentModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileUrl,
    this.userId,
    this.userName,
  });

  factory TaskAttachmentModel.fromJson(Map<String, dynamic> json) {
    String path = json['file_path']?.toString() ?? '';
    String url = json['file_url']?.toString() ?? '';
    if (url.isEmpty && path.isNotEmpty) {
      url = path.startsWith('http') ? path : 'https://hrms.tulsifabindia.com/storage/$path';
    } else if (url.isNotEmpty && !url.startsWith('http')) {
      url = url.startsWith('/') ? 'https://hrms.tulsifabindia.com$url' : 'https://hrms.tulsifabindia.com/$url';
    }

    String fName = json['file_name']?.toString() ?? '';
    if (fName.isEmpty) {
      fName = path.isNotEmpty ? path.split('/').last : 'attachment';
    }

    return TaskAttachmentModel(
      id: json['id'] ?? 0,
      fileName: fName,
      filePath: path,
      fileUrl: url,
      userId: json['user_id'],
      userName: json['user_name'],
    );
  }
}

class TaskCategoryModel {
  final int id;
  final String name;
  final String color;
  final String? description;

  TaskCategoryModel({
    required this.id,
    required this.name,
    required this.color,
    this.description,
  });

  factory TaskCategoryModel.fromJson(Map<String, dynamic> json) {
    return TaskCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'] ?? '#6366f1',
      description: json['description'],
    );
  }
}

class TaskReplyModel {
  final int id;
  final int userId;
  final String userName;
  final String? userPhoto;
  final String message;
  final String? attachmentUrl;
  final List<String> attachments;
  final String? createdAt;

  TaskReplyModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.message,
    this.attachmentUrl,
    this.attachments = const [],
    this.createdAt,
  });

  factory TaskReplyModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedAtts = [];
    if (json['attachments'] is List) {
      for (var x in json['attachments']) {
        if (x is Map && x['url'] != null) {
          parsedAtts.add(x['url'].toString());
        } else if (x != null) {
          parsedAtts.add(x.toString());
        }
      }
    } else if (json['attachment_urls'] is List) {
      parsedAtts = List<String>.from(json['attachment_urls'].map((x) => x.toString()));
    } else if (json['attachment_url'] != null && json['attachment_url'].toString().isNotEmpty) {
      parsedAtts = [json['attachment_url'].toString()];
    }

    List<String> normalizedAtts = [];
    for (var u in parsedAtts) {
      if (!u.startsWith('http')) {
        u = u.startsWith('/')
            ? 'https://hrms.tulsifabindia.com$u'
            : (u.startsWith('storage/') ? 'https://hrms.tulsifabindia.com/$u' : 'https://hrms.tulsifabindia.com/storage/$u');
      }
      normalizedAtts.add(u);
    }

    String? singleAtt = json['attachment_url']?.toString();
    if (singleAtt != null && singleAtt.isNotEmpty && !singleAtt.startsWith('http')) {
      singleAtt = singleAtt.startsWith('/')
          ? 'https://hrms.tulsifabindia.com$singleAtt'
          : (singleAtt.startsWith('storage/') ? 'https://hrms.tulsifabindia.com/$singleAtt' : 'https://hrms.tulsifabindia.com/storage/$singleAtt');
    }

    return TaskReplyModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'User',
      userPhoto: json['user_photo'],
      message: json['message'] ?? '',
      attachmentUrl: singleAtt ?? (normalizedAtts.isNotEmpty ? normalizedAtts.first : null),
      attachments: normalizedAtts,
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
  final bool isPinned;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
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
  final List<TaskAttachmentModel> attachments;
  final int repliesCount;
  final List<TaskReplyModel> replies;
  final List<TaskHistoryModel> histories;
  final List<dynamic> assignees;
  final List<dynamic> others;
  final String? createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.isPinned = false,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
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
    this.attachments = const [],
    this.repliesCount = 0,
    this.replies = const [],
    this.histories = const [],
    this.assignees = const [],
    this.others = const [],
    this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    var rawReplies = json['replies'] as List? ?? [];
    List<TaskReplyModel> parsedReplies = rawReplies.map((x) => TaskReplyModel.fromJson(x)).toList();

    var rawHistories = json['histories'] as List? ?? [];
    List<TaskHistoryModel> parsedHistories = rawHistories.map((x) => TaskHistoryModel.fromJson(x)).toList();

    var rawAttachments = json['attachments'] as List? ?? [];
    List<TaskAttachmentModel> parsedAttachments = rawAttachments.map((x) => TaskAttachmentModel.fromJson(x)).toList();

    String? attUrl = json['attachment_url']?.toString();
    if (attUrl != null && attUrl.isNotEmpty && !attUrl.startsWith('http')) {
      attUrl = attUrl.startsWith('/')
          ? 'https://hrms.tulsifabindia.com$attUrl'
          : (attUrl.startsWith('storage/') ? 'https://hrms.tulsifabindia.com/$attUrl' : 'https://hrms.tulsifabindia.com/storage/$attUrl');
    }

    return TaskModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      categoryColor: json['category_color'],
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
      attachmentUrl: attUrl,
      attachments: parsedAttachments,
      repliesCount: json['replies_count'] ?? parsedReplies.length,
      replies: parsedReplies,
      histories: parsedHistories,
      assignees: json['assignees'] as List? ?? [],
      others: json['others'] as List? ?? [],
      createdAt: json['created_at'],
    );
  }

  String? get assigneeName => assignedToName;
}
