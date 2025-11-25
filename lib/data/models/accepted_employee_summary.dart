/// Données minimales stockées avec la demande lorsqu'un employé est accepté
class AcceptedEmployeeSummary {
  final String id;
  final String? name;
  final String? service;
  final String? city;
  final double? rating;
  final String? photoUrl;
  final String? phone;

  const AcceptedEmployeeSummary({
    required this.id,
    this.name,
    this.service,
    this.city,
    this.rating,
    this.photoUrl,
    this.phone,
  });

  factory AcceptedEmployeeSummary.fromMap(Map<String, dynamic> map) {
    return AcceptedEmployeeSummary(
      id: map['id'] ?? '',
      name: map['name'],
      service: map['service'],
      city: map['city'],
      rating: (map['rating'] as num?)?.toDouble(),
      photoUrl: map['photoUrl'],
      phone: map['phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (service != null) 'service': service,
      if (city != null) 'city': city,
      if (rating != null) 'rating': rating,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (phone != null) 'phone': phone,
    };
  }

  AcceptedEmployeeSummary copyWith({
    String? id,
    String? name,
    String? service,
    String? city,
    double? rating,
    String? photoUrl,
    String? phone,
  }) {
    return AcceptedEmployeeSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      service: service ?? this.service,
      city: city ?? this.city,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
    );
  }
}

