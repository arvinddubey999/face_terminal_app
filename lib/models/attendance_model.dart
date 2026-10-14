class PunchModel {
  final int id;
  final String type;
  final String source;
  final String time;
  final String at;
  final String? location;
  final String? photo;
  final String? greeting;

  PunchModel({
    required this.id,
    required this.type,
    required this.source,
    required this.time,
    required this.at,
    this.location,
    this.photo,
    this.greeting,
  });

  factory PunchModel.fromJson(Map<String, dynamic> json) {
    return PunchModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'in',
      source: json['source'] ?? 'mobile',
      time: json['time'] ?? '',
      at: json['at'] ?? '',
      location: json['location'],
      photo: json['photo'],
      greeting: json['greeting'],
    );
  }
}
