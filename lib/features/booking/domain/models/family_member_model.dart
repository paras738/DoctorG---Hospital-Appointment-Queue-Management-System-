class FamilyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String relationship; // Spouse, Child, Parent, Sibling, Other
  final int age;
  final String gender; // Male, Female, Other

  const FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.age,
    required this.gender,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String? ?? 'Family Member',
      age: (json['age'] as num).toInt(),
      gender: json['gender'] as String? ?? 'Other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'age': age,
      'gender': gender,
    };
  }
}
