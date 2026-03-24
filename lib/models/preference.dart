import 'dart:convert';

/// A user preference stored in the encrypted local vault.
///
/// Preferences are key-value pairs with optional tags that persist
/// across sessions. They are included in context queries alongside
/// vault entries, and go through the same redaction pipeline.
class Preference {
  final String id;
  final String key;
  final String value;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Preference({
    required this.id,
    required this.key,
    required this.value,
    this.tags = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'key': key,
        'value': value,
        'tags': tags.isNotEmpty ? jsonEncode(tags) : null,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Preference.fromMap(Map<String, dynamic> map) {
    final String? rawTags = map['tags'] as String?;
    final List<String> parsedTags = rawTags != null && rawTags.isNotEmpty
        ? (jsonDecode(rawTags) as List<dynamic>).cast<String>()
        : <String>[];

    return Preference(
      id: map['id'] as String,
      key: map['key'] as String,
      value: map['value'] as String,
      tags: parsedTags,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Preference copyWith({
    String? id,
    String? key,
    String? value,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Preference(
        id: id ?? this.id,
        key: key ?? this.key,
        value: value ?? this.value,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Preference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          key == other.key &&
          value == other.value &&
          _listEquals(tags, other.tags) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        key,
        value,
        Object.hashAll(tags),
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Preference(key: $key)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
