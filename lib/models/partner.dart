/// Model partnera — mapuje tabulku `partners` v Supabase.
///
/// SQL schema:
/// ```sql
/// CREATE TABLE partners (
///   id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
///   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
///   jmeno TEXT NOT NULL,
///   firma TEXT,
///   telefon TEXT NOT NULL,
///   email TEXT NOT NULL,
///   kategorie TEXT NOT NULL CHECK (kategorie IN ('zamecnik','odtahovka','servis','instalater')),
///   adresa TEXT,
///   lat DOUBLE PRECISION,
///   lng DOUBLE PRECISION,
///   zona TEXT DEFAULT 'praha',
///   hodnoceni NUMERIC(2,1) DEFAULT 5.0,
///   pocet_recenzi INT DEFAULT 0,
///   is_online BOOLEAN DEFAULT false,
///   foto_url TEXT,
///   created_at TIMESTAMPTZ DEFAULT now()
/// );
/// ```
class Partner {
  final String id;
  final String? userId;
  final String jmeno;
  final String? firma;
  final String telefon;
  final String email;
  final String kategorie;
  final String? adresa;
  final double? lat;
  final double? lng;
  final String zona;
  final double hodnoceni;
  final int pocetRecenzi;
  final bool isOnline;
  final String? fotoUrl;
  final DateTime createdAt;

  const Partner({
    required this.id,
    this.userId,
    required this.jmeno,
    this.firma,
    required this.telefon,
    required this.email,
    required this.kategorie,
    this.adresa,
    this.lat,
    this.lng,
    this.zona = 'praha',
    this.hodnoceni = 5.0,
    this.pocetRecenzi = 0,
    this.isOnline = false,
    this.fotoUrl,
    required this.createdAt,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      jmeno: json['jmeno'] as String,
      firma: json['firma'] as String?,
      telefon: json['telefon'] as String,
      email: json['email'] as String,
      kategorie: json['kategorie'] as String,
      adresa: json['adresa'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      zona: json['zona'] as String? ?? 'praha',
      hodnoceni: (json['hodnoceni'] as num?)?.toDouble() ?? 5.0,
      pocetRecenzi: json['pocet_recenzi'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      fotoUrl: json['foto_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'jmeno': jmeno,
      'firma': firma,
      'telefon': telefon,
      'email': email,
      'kategorie': kategorie,
      'adresa': adresa,
      'lat': lat,
      'lng': lng,
      'zona': zona,
      'hodnoceni': hodnoceni,
      'pocet_recenzi': pocetRecenzi,
      'is_online': isOnline,
      'foto_url': fotoUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Partner copyWith({
    String? id,
    String? userId,
    String? jmeno,
    String? firma,
    String? telefon,
    String? email,
    String? kategorie,
    String? adresa,
    double? lat,
    double? lng,
    String? zona,
    double? hodnoceni,
    int? pocetRecenzi,
    bool? isOnline,
    String? fotoUrl,
    DateTime? createdAt,
  }) {
    return Partner(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      jmeno: jmeno ?? this.jmeno,
      firma: firma ?? this.firma,
      telefon: telefon ?? this.telefon,
      email: email ?? this.email,
      kategorie: kategorie ?? this.kategorie,
      adresa: adresa ?? this.adresa,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      zona: zona ?? this.zona,
      hodnoceni: hodnoceni ?? this.hodnoceni,
      pocetRecenzi: pocetRecenzi ?? this.pocetRecenzi,
      isOnline: isOnline ?? this.isOnline,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
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
}
