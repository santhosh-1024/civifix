class Complaint {
  final String id;
  final String userId;
  final String type;
  final String description;
  final String status;
  final String priority;
  final String? department;
  final String? assignedTeam;
  final String imageUrl;
  final String? afterImageUrl;
  final String? remarks;
  final int upvotes;
  final bool isOpen;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.status,
    required this.priority,
    required this.imageUrl,
    required this.upvotes,
    required this.isOpen,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.updatedAt,
    this.department,
    this.assignedTeam,
    this.afterImageUrl,
    this.remarks,
  });

  factory Complaint.fromMap(String id, Map<String, dynamic> map) {
    return Complaint(
      id: id,
      userId: map["userId"],
      type: map["type"],
      description: map["description"],
      status: map["status"],
      priority: map["priority"] ?? "medium",
      department: map["department"],
      assignedTeam: map["assignedTeam"],
      imageUrl: map["imageUrl"],
      afterImageUrl: map["afterImageUrl"],
      remarks: map["remarks"],
      upvotes: map["upvotes"] ?? 0,
      isOpen: map["isOpen"] ?? true,
      lat: (map["location"]["lat"] as num).toDouble(),
      lng: (map["location"]["lng"] as num).toDouble(),
      createdAt: (map["createdAt"] as dynamic).toDate(),
      updatedAt: (map["updatedAt"] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "userId": userId,
        "type": type,
        "description": description,
        "status": status,
        "priority": priority,
        "department": department,
        "assignedTeam": assignedTeam,
        "imageUrl": imageUrl,
        "afterImageUrl": afterImageUrl,
        "remarks": remarks,
        "upvotes": upvotes,
        "isOpen": isOpen,
        "location": {"lat": lat, "lng": lng},
        "createdAt": createdAt,
        "updatedAt": updatedAt,
      };
}
