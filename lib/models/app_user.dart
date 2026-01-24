class AppUser {
  final String uid;
  final String? name;
  final String? phone;
  final String? email;
  final String role;

  AppUser({
    required this.uid,
    this.name,
    this.phone,
    this.email,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map["uid"],
      name: map["name"],
      phone: map["phone"],
      email: map["email"],
      role: map["role"] ?? "citizen",
    );
  }

  Map<String, dynamic> toMap() => {
        "uid": uid,
        "name": name,
        "phone": phone,
        "email": email,
        "role": role,
        "createdAt": DateTime.now(),
      };
}
