/// Model SOS požadavku — mapuje tabulku `sos_requests` v Supabase.
///
/// SQL schema:
/// ```sql
/// CREATE TABLE sos_requests (
///   id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
///   customer_id UUID,
///   kategorie TEXT NOT NULL CHECK (kategorie IN ('zamecnik','odtahovka','servis','instalater')),
///   popis TEXT,
///   lat DOUBLE PRECISION NOT NULL,
///   lng DOUBLE PRECISION NOT NULL,
///   adresa TEXT,
///   status TEXT NOT NULL DEFAULT 'pending'
///     CHECK (status IN ('pending','accepted','in_progress','completed','cancelled')),
///   accepted_by UUID REFERENCES partners(id),
///   accepted_at TIMESTAMPTZ,
///   completed_at TIMESTAMPTZ,
///   created_at TIMESTAMPTZ DEFAULT now()
/// );
/// ```
enum SosStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled;

  String get dbValue {
    switch (this) {
      case SosStatus.pending:
        return 'pending';
      case SosStatus.accepted:
        return 'accepted';
      case SosStatus.inProgress:
        return 'in_progress';
      case SosStatus.completed:
        return 'completed';
      case SosStatus.cancelled:
        return 'cancelled';
    }
  }

  static SosStatus fromDb(String value) {
    switch (value) {
      case 'pending':
        return SosStatus.pending;
      case 'accepted':
        return SosStatus.accepted;
      case 'in_progress':
        return SosStatus.inProgress;
      case 'completed':
        return SosStatus.completed;
      case 'cancelled':
        return SosStatus.cancelled;
      default:
        return SosStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case SosStatus.pending:
        return 'Čeká na přijetí';
      case SosStatus.accepted:
        return 'Přijato';
      case SosStatus.inProgress:
        return 'Na cestě';
      case SosStatus.completed:
        return 'Dokončeno';
      case SosStatus.cancelled:
        return 'Zrušeno';
    }
  }

  bool get isActive =>
      this == SosStatus.pending ||
      this == SosStatus.accepted ||
      this == SosStatus.inProgress;
}

class SosRequest {
  final String id;
  final String? customerId;
  final String kategorie;
  final String? popis;
  final double lat;
  final double lng;
  final String? adresa;
  final SosStatus status;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const SosRequest({
    required this.id,
    this.customerId,
    required this.kategorie,
    this.popis,
    required this.lat,
    required this.lng,
    this.adresa,
    this.status = SosStatus.pending,
    this.acceptedBy,
    this.acceptedAt,
    this.completedAt,
    required this.createdAt,
  });

  factory SosRequest.fromJson(Map<String, dynamic> json) {
    return SosRequest(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      kategorie: json['kategorie'] as String,
      popis: json['popis'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      adresa: json['adresa'] as String?,
      status: SosStatus.fromDb(json['status'] as String? ?? 'pending'),
      acceptedBy: json['accepted_by'] as String?,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'kategorie': kategorie,
      'popis': popis,
      'lat': lat,
      'lng': lng,
      'adresa': adresa,
      'status': status.dbValue,
      'accepted_by': acceptedBy,
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  SosRequest copyWith({
    SosStatus? status,
    String? acceptedBy,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return SosRequest(
      id: id,
      customerId: customerId,
      kategorie: kategorie,
      popis: popis,
      lat: lat,
      lng: lng,
      adresa: adresa,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }

  /// Český label pro kategorii
  String get kategorieLabel {
    switch (kategorie) {
      case 'zamecnik':
        return 'Zámečník';
      case 'odtahovka':
        return 'Odtahovka';
      case 'servis':
        return 'Servisy';
      case 'instalater':
        return 'Hav. Instalatér';
      default:
        return kategorie;
    }
  }

  /// Vzdálenost od partnera (placeholder — implementace v budoucnu s geolocator)
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'právě teď';
    if (diff.inMinutes < 60) return 'před ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'před ${diff.inHours} h';
    return 'před ${diff.inDays} dny';
  }
}
