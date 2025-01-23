class Item {
  final String id;
  final String name;
  final String location;
  final String expiryDate;
  final String? imagePath;
  final String addedDate;

  Item({
    required this.id,
    required this.name,
    required this.location,
    required this.expiryDate,
    this.imagePath,
    required this.addedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'expiryDate': expiryDate,
      'imagePath': imagePath,
      'addedDate': addedDate,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      expiryDate: json['expiryDate'] as String,
      imagePath: json['imagePath'] as String?,
      addedDate: json['addedDate'] as String,
    );
  }

  Item copyWith({
    String? id,
    String? name,
    String? location,
    String? expiryDate,
    String? imagePath,
    String? addedDate,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      addedDate: addedDate ?? this.addedDate,
    );
  }
}
