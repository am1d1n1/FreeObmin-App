part of '../main.dart';

/* ===========================
        MODELS
=========================== */

enum ItemType { exchange, gift }

extension ItemTypeX on ItemType {
  String get label => this == ItemType.exchange ? 'Обмін' : 'Подарунок';
  IconData get icon => this == ItemType.exchange
      ? Icons.swap_horiz_rounded
      : Icons.card_giftcard_rounded;
  Color get accent => this == ItemType.exchange
      ? const Color(0xFF10B981)
      : const Color(0xFF8B5CF6);
}

enum ItemStatus { pending, approved, rejected }

extension ItemStatusX on ItemStatus {
  String get label {
    switch (this) {
      case ItemStatus.pending:
        return 'На модерації';
      case ItemStatus.approved:
        return 'Схвалено';
      case ItemStatus.rejected:
        return 'Відхилено';
    }
  }

  Color get color {
    switch (this) {
      case ItemStatus.pending:
        return const Color(0xFFF59E0B);
      case ItemStatus.approved:
        return const Color(0xFF10B981);
      case ItemStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case ItemStatus.pending:
        return Icons.pending_rounded;
      case ItemStatus.approved:
        return Icons.check_circle_rounded;
      case ItemStatus.rejected:
        return Icons.cancel_rounded;
    }
  }
}

String _slugifyTitle(String input) {
  const map = {
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'h',
    'ґ': 'g',
    'д': 'd',
    'е': 'e',
    'є': 'ye',
    'ж': 'zh',
    'з': 'z',
    'и': 'y',
    'і': 'i',
    'ї': 'yi',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'kh',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'shch',
    'ь': '',
    'ы': 'y',
    'ъ': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
  };

  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (map.containsKey(char)) {
      buffer.write(map[char]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write('-');
    }
  }

  final slug = buffer
      .toString()
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'item' : slug;
}

String? _extractItemIdFromUri(Uri uri) {
  final queryId = uri.queryParameters['id'];
  if (queryId != null && queryId.isNotEmpty) return queryId;
  final queryItem = uri.queryParameters['item'];
  if (queryItem != null && queryItem.isNotEmpty) return queryItem;

  final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  if (path.isEmpty) return null;

  final match = RegExp(r'i_([A-Za-z0-9]+)').firstMatch(path);
  if (match != null) return match.group(1);

  final idPattern = RegExp(r'^[A-Za-z0-9]{8,}$');
  if (path.contains('-')) {
    final tail = path.split('-').last;
    if (idPattern.hasMatch(tail)) return tail;
  }

  if (idPattern.hasMatch(path)) return path;
  return null;
}

String? _extractShortCodeFromUri(Uri uri) {
  final queryCode = uri.queryParameters['code'];
  if (queryCode != null && queryCode.isNotEmpty) return queryCode;
  final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  if (path.isEmpty) return null;
  if (path.contains('_')) {
    final tail = path.split('_').last;
    if (RegExp(r'^[a-z0-9]{5,10}$').hasMatch(tail)) return tail;
  }
  return null;
}

class Item {
  final String id;
  final String title;
  final String desc;
  final String city;
  final String category;
  final ItemType type;
  final ItemStatus status;
  int likes;
  int views;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> photoPaths;
  final List<String> photoUrls;
  final List<String> localImagePaths;
  final int mainImageIndex;
  final String? moderationComment;
  final bool needsRevision;

  Item({
    required this.id,
    required this.title,
    required this.desc,
    required this.city,
    required this.category,
    required this.type,
    this.status = ItemStatus.pending,
    required this.likes,
    required this.views,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.createdAt,
    this.updatedAt,
    required this.photoPaths,
    required this.photoUrls,
    this.localImagePaths = const [],
    this.mainImageIndex = 0,
    this.moderationComment,
    this.needsRevision = false,
  });

  List<String> get allPhotos {
    final primary =
        photoUrls.isNotEmpty ? photoUrls : localImagePaths;
    final unique = <String>[];
    for (final photo in primary) {
      if (photo.isEmpty) continue;
      if (!unique.contains(photo)) {
        unique.add(photo);
      }
    }
    return unique;
  }

  String _thumbUrl(String url) {
    if (!url.startsWith('http')) return url;
    const marker = '/upload/';
    if (!url.contains(marker)) return url;
    return url.replaceFirst(marker, '${marker}w_600,q_auto,f_auto/');
  }

  String get mainPhoto {
    final allPhotos = this.allPhotos;
    if (allPhotos.isEmpty) return '';
    if (mainImageIndex < allPhotos.length) {
      return allPhotos[mainImageIndex];
    }
    return allPhotos.first;
  }

  Item copyWith({
    String? id,
    String? title,
    String? desc,
    String? city,
    String? category,
    ItemType? type,
    ItemStatus? status,
    int? likes,
    int? views,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? photoPaths,
    List<String>? photoUrls,
    List<String>? localImagePaths,
    int? mainImageIndex,
    String? moderationComment,
    bool? needsRevision,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      city: city ?? this.city,
      category: category ?? this.category,
      type: type ?? this.type,
      status: status ?? this.status,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      photoPaths: photoPaths ?? this.photoPaths,
      photoUrls: photoUrls ?? this.photoUrls,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      mainImageIndex: mainImageIndex ?? this.mainImageIndex,
      moderationComment: moderationComment ?? this.moderationComment,
      needsRevision: needsRevision ?? this.needsRevision,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': desc,
        'city': city,
        'category': category,
        'type': type == ItemType.exchange ? 'exchange' : 'gift',
        'status': status == ItemStatus.pending
            ? 'pending'
            : status == ItemStatus.approved
                ? 'approved'
                : 'rejected',
        'likes': likes,
        'views': views,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'ownerEmail': ownerEmail,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'photoPaths': photoPaths,
        'photoUrls': photoUrls,
        'images': photoUrls,
        'localImagePaths': localImagePaths,
        'mainImageIndex': mainImageIndex,
        'moderationComment': moderationComment,
        'needsRevision': needsRevision,
      };

  static Item fromJson(Map<String, dynamic> json) {
    String strValue(String key, String fallback) {
      final value = json[key];
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    List<String> listValue(String key) {
      final raw = json[key] as List?;
      if (raw == null) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value.toString().trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    final parsedPhotoUrls = listValue('photoUrls');
    final resolvedPhotoUrls =
        parsedPhotoUrls.isEmpty ? listValue('images') : parsedPhotoUrls;

    return Item(
      id: strValue('id', 'unknown'),
      title: strValue('title', 'Без названия'),
      desc: strValue('desc', ''),
      city: strValue('city', ''),
      category: strValue('category', ''),
      type: (json['type'] as String? ?? 'exchange') == 'exchange'
          ? ItemType.exchange
          : ItemType.gift,
      status: (json['status'] as String? ?? 'pending') == 'pending'
          ? ItemStatus.pending
          : (json['status'] == 'approved'
              ? ItemStatus.approved
              : ItemStatus.rejected),
      likes: (json['likes'] ?? 0) as int,
      views: (json['views'] ?? 0) as int,
      ownerId: strValue('ownerId', 'u_unknown'),
      ownerName: strValue('ownerName', 'Користувач'),
      ownerEmail: strValue('ownerEmail', 'user@example.com'),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseNullableDate(json['updatedAt']),
      photoPaths: listValue('photoPaths'),
      photoUrls: resolvedPhotoUrls,
      localImagePaths: listValue('localImagePaths'),
      mainImageIndex: (json['mainImageIndex'] ?? 0) as int,
      moderationComment: json['moderationComment']?.toString(),
      needsRevision: parseBool(json['needsRevision']),
    );
  }

  Widget getImageWidget(BuildContext context,
      {double iconSize = 40, BoxFit fit = BoxFit.cover}) {
    final cs = Theme.of(context).colorScheme;
    final displayUrl = _thumbUrl(mainPhoto);

    if (mainPhoto.isEmpty) {
      return Container(
        color: cs.surfaceContainer,
        child: Center(
          child: Icon(
            type.icon,
            color: cs.onSurface.withAlpha(77),
            size: iconSize,
          ),
        ),
      );
    }

    if (displayUrl.startsWith('http') || displayUrl.startsWith('https')) {
      return CachedNetworkImage(
        imageUrl: displayUrl,
        fit: fit,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: NeoThemes.currentColor,
          ),
        ),
        errorWidget: (context, url, error) {
          return Container(
            color: cs.surfaceContainer,
            child: Center(
              child: Icon(
                type.icon,
                color: cs.onSurface.withAlpha(77),
                size: iconSize,
              ),
            ),
          );
        },
      );
    } else {
      try {
        final uri = Uri.tryParse(mainPhoto);
        final filePath = uri?.scheme == 'file' ? uri!.toFilePath() : mainPhoto;
        return Image.file(
          File(filePath),
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: cs.surfaceContainer,
              child: Center(
                child: Icon(
                  type.icon,
                  color: cs.onSurface.withAlpha(77),
                  size: iconSize,
                ),
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          color: cs.surfaceContainer,
          child: Center(
            child: Icon(
              type.icon,
              color: cs.onSurface.withAlpha(77),
              size: iconSize,
            ),
          ),
        );
      }
    }
  }

  Widget getImageAtIndex(BuildContext context, int index,
      {double iconSize = 40, BoxFit fit = BoxFit.cover}) {
    final cs = Theme.of(context).colorScheme;
    final photos = allPhotos;

    if (index >= photos.length || photos.isEmpty) {
      return Container(
        color: cs.surfaceContainer,
        child: Center(
          child: Icon(
            type.icon,
            color: cs.onSurface.withAlpha(77),
            size: iconSize,
          ),
        ),
      );
    }

    final photo = photos[index];

    if (photo.startsWith('http') || photo.startsWith('https')) {
      return CachedNetworkImage(
        imageUrl: photo,
        fit: fit,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: NeoThemes.currentColor,
          ),
        ),
        errorWidget: (context, url, error) {
          return Container(
            color: cs.surfaceContainer,
            child: Center(
              child: Icon(
                type.icon,
                color: cs.onSurface.withAlpha(77),
                size: iconSize,
              ),
            ),
          );
        },
      );
    } else {
      try {
        final uri = Uri.tryParse(photo);
        final filePath = uri?.scheme == 'file' ? uri!.toFilePath() : photo;
        return Image.file(
          File(filePath),
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: cs.surfaceContainer,
              child: Center(
                child: Icon(
                  type.icon,
                  color: cs.onSurface.withAlpha(77),
                  size: iconSize,
                ),
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          color: cs.surfaceContainer,
          child: Center(
            child: Icon(
              type.icon,
              color: cs.onSurface.withAlpha(77),
              size: iconSize,
            ),
          ),
        );
      }
    }
  }
}

enum MessageType { text, image }

class ChatMessage {
  final String id;
  final String text;
  final bool fromMe;
  final DateTime at;
  final MessageType type;
  final String? imagePath;
  final String? imageUrl;
  final String? itemId;
  final String? itemTitle;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromMe,
    required this.at,
    this.type = MessageType.text,
    this.imagePath,
    this.imageUrl,
    this.itemId,
    this.itemTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'fromMe': fromMe,
        'at': at.toIso8601String(),
        'type': type == MessageType.text ? 'text' : 'image',
        'imagePath': imagePath,
        'imageUrl': imageUrl,
        'itemId': itemId,
        'itemTitle': itemTitle,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        text: json['text'],
        fromMe: json['fromMe'] == true,
        at: DateTime.tryParse(json['at'] ?? '') ?? DateTime.now(),
        type: (json['type'] as String? ?? 'text') == 'text'
            ? MessageType.text
            : MessageType.image,
        imagePath: json['imagePath'],
        imageUrl: json['imageUrl'],
        itemId: json['itemId'],
        itemTitle: json['itemTitle'],
      );
}

class ChatThread {
  final String id;
  final String peerId;
  final String peerName;
  final String peerEmail;
  final List<ChatMessage> messages;
  int unread;
  final String? relatedItemId;
  final Map<String, DateTime> lastRead;
  final Set<String> blockedUsers;

  ChatThread({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerEmail,
    required this.messages,
    this.unread = 0,
    this.relatedItemId,
    Map<String, DateTime>? lastRead,
    Set<String>? blockedUsers,
  })  : lastRead = lastRead ?? {},
        blockedUsers = blockedUsers ?? {};

  ChatMessage get last => messages.isNotEmpty
      ? messages.last
      : ChatMessage(
          id: 'm0', text: 'Начните диалог', fromMe: false, at: DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerId': peerId,
        'peerName': peerName,
        'peerEmail': peerEmail,
        'unread': unread,
        'relatedItemId': relatedItemId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'lastRead': lastRead
            .map((key, value) => MapEntry(key, value.toIso8601String())),
        'blockedUsers': blockedUsers.toList(),
      };

  static ChatThread fromJson(Map<String, dynamic> json) {
    final rawLastRead = Map<String, dynamic>.from(json['lastRead'] ?? {});
    final lastRead = <String, DateTime>{};
    rawLastRead.forEach((key, value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        lastRead[key] = parsed;
      }
    });

    final blockedUsers = <String>{};
    final rawBlocked = json['blockedUsers'];
    if (rawBlocked is Map) {
      rawBlocked.forEach((key, value) {
        if (value == true) {
          blockedUsers.add(key.toString());
        }
      });
    } else if (rawBlocked is List) {
      for (final entry in rawBlocked) {
        if (entry == null) continue;
        blockedUsers.add(entry.toString());
      }
    }

    return ChatThread(
      id: json['id'],
      peerId: json['peerId'],
      peerName: json['peerName'],
      peerEmail: json['peerEmail'] ?? 'user@example.com',
      unread: (json['unread'] ?? 0) as int,
      relatedItemId: json['relatedItemId'],
      lastRead: lastRead,
      blockedUsers: blockedUsers,
      messages: (json['messages'] as List? ?? const [])
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AppNotification {
  final String id;
  final String toUserId;
  final String fromUserId;
  final String fromName;
  final String chatId;
  final String itemId;
  final String action;
  final String? comment;
  final String title;
  final String body;
  final String status; // sent, failed, pending
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.toUserId,
    required this.fromUserId,
    required this.fromName,
    required this.chatId,
    required this.itemId,
    required this.action,
    this.comment,
    required this.title,
    required this.body,
    required this.status,
    required this.read,
    required this.createdAt,
  });

  AppNotification copyWith(
      {String? status, bool? read, String? action, String? comment}) {
    return AppNotification(
      id: id,
      toUserId: toUserId,
      fromUserId: fromUserId,
      fromName: fromName,
      chatId: chatId,
      itemId: itemId,
      action: action ?? this.action,
      comment: comment ?? this.comment,
      title: title,
      body: body,
      status: status ?? this.status,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }

  static AppNotification fromJson(String id, Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return AppNotification(
      id: id,
      toUserId: (json['toКористувачId'] ?? '').toString(),
      fromUserId: (json['fromКористувачId'] ?? '').toString(),
      fromName: (json['fromName'] ?? 'Користувач').toString(),
      chatId: (json['chatId'] ?? '').toString(),
      itemId: (json['itemId'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      comment: json['comment']?.toString(),
      title: (json['title'] ?? 'Нове повідомлення').toString(),
      body: (json['body'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      read: json['read'] == true,
      createdAt: parseDate(json['createdAt']),
    );
  }
}

class Complaint {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final String reason;
  final String? itemId;
  final String? itemTitle;
  final DateTime createdAt;
  final String status; // open, accepted, rejected
  final String? moderatorId;
  final String? moderatorName;
  final DateTime? resolvedAt;

  const Complaint({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reason,
    this.itemId,
    this.itemTitle,
    required this.createdAt,
    required this.status,
    this.moderatorId,
    this.moderatorName,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reportedКористувачId': reportedUserId,
        'reportedКористувачName': reportedUserName,
        'reason': reason,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'moderatorId': moderatorId,
        'moderatorName': moderatorName,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  static Complaint fromJson(String id, Map<String, dynamic> json) {
    return Complaint(
      id: id,
      reporterId: (json['reporterId'] ?? '').toString(),
      reporterName: (json['reporterName'] ?? '').toString(),
      reportedUserId: (json['reportedКористувачId'] ?? '').toString(),
      reportedUserName: (json['reportedКористувачName'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      itemId: json['itemId']?.toString(),
      itemTitle: json['itemTitle']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      status: (json['status'] ?? 'open').toString(),
      moderatorId: json['moderatorId']?.toString(),
      moderatorName: json['moderatorName']?.toString(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
    );
  }
}

class LocationCity {
  final String name;
  final String type;
  final List<String> districts;

  const LocationCity({
    required this.name,
    required this.type,
    required this.districts,
  });

  factory LocationCity.fromJson(Map<String, dynamic> json) {
    return LocationCity(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      districts: (json['districts'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class LocationSelection {
  final String region;
  final String district;
  final LocationCity city;

  const LocationSelection({
    required this.region,
    required this.district,
    required this.city,
  });
}

class LocationData {
  final Map<String, Map<String, List<LocationCity>>> data;

  const LocationData(this.data);

  List<String> get regions {
    final list = data.keys.toList()..sort();
    return list;
  }

  List<String> districtsFor(String region) {
    final districts = data[region]?.keys.toList() ?? const [];
    districts.sort();
    return districts;
  }

  List<LocationCity> citiesFor(String region, String district) {
    return data[region]?[district] ?? const [];
  }

  LocationSelection? findCity(String cityName) {
    final needle = cityName.trim().toLowerCase();
    if (needle.isEmpty) return null;

    for (final entry in data.entries) {
      final region = entry.key;
      for (final districtEntry in entry.value.entries) {
        final district = districtEntry.key;
        for (final city in districtEntry.value) {
          if (city.name.toLowerCase() == needle) {
            return LocationSelection(
              region: region,
              district: district,
              city: city,
            );
          }
        }
      }
    }
    return null;
  }

  static Future<LocationData> load() async {
    final raw = await rootBundle.loadString('lib/locations.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, Map<String, List<LocationCity>>> data = {};

    decoded.forEach((regionName, districtsRaw) {
      final districtMap = <String, List<LocationCity>>{};
      final districts = districtsRaw as Map<String, dynamic>;
      districts.forEach((districtName, citiesRaw) {
        final list = (citiesRaw as List)
            .map((e) => LocationCity.fromJson(
                e as Map<String, dynamic>? ?? const {}))
            .where((city) => city.name.isNotEmpty)
            .toList();
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        districtMap[districtName] = list;
      });
      data[regionName] = districtMap;
    });

    return LocationData(data);
  }
}

enum UserRole { user, moderator, admin }

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int progress;
  final int target;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.progress,
    required this.target,
    required this.unlocked,
  });
}

class SessionUser {
  final String uid;
  String name;
  final String email;
  String city;
  final UserRole role;
  int likes;
  int level;
  int itemsPosted;
  int itemsApproved;
  int exchangesCompleted;
  DateTime? lastAchievementUpdate;
  DateTime? createdAt;
  String? phone;
  String? currentPassword;
  String? profileImagePath;
  String? profileImageUrl; // Добавлено для хранения URL из Firebase Storage
  bool isBlocked;
  String? blockedById;
  String? blockedByName;
  String? blockedReason;
  DateTime? blockedAt;

  SessionUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.city,
    required this.role,
    required this.likes,
    required this.level,
    this.itemsPosted = 0,
    this.itemsApproved = 0,
    this.exchangesCompleted = 0,
    this.lastAchievementUpdate,
    this.createdAt,
    this.phone,
    this.currentPassword,
    this.profileImagePath,
    this.profileImageUrl,
    this.isBlocked = false,
    this.blockedById,
    this.blockedByName,
    this.blockedReason,
    this.blockedAt,
  });

  bool get isModerator => role == UserRole.moderator || role == UserRole.admin;
  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'city': city,
        'role': role == UserRole.user
            ? 'user'
            : role == UserRole.moderator
                ? 'moderator'
                : 'admin',
        'likes': likes,
        'level': level,
        'itemsPosted': itemsPosted,
        'itemsApproved': itemsApproved,
        'exchangesCompleted': exchangesCompleted,
        'lastAchievementUpdate': lastAchievementUpdate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'phone': phone,
        'profileImagePath': profileImagePath,
        'profileImageUrl': profileImageUrl,
        'isBlocked': isBlocked,
        'blockedById': blockedById,
        'blockedByName': blockedByName,
        'blockedReason': blockedReason,
        'blockedAt': blockedAt?.toIso8601String(),
      };

  static SessionUser fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'user';
    return SessionUser(
      uid: json['uid'],
      name: json['name'],
      email: json['email'],
      city: json['city'],
      role: roleStr == 'moderator'
          ? UserRole.moderator
          : roleStr == 'admin'
              ? UserRole.admin
              : UserRole.user,
      likes: (json['likes'] ?? 0) as int,
      level: (json['level'] ?? 1) as int,
      itemsPosted: (json['itemsPosted'] ?? 0) as int,
      itemsApproved: (json['itemsApproved'] ?? 0) as int,
      exchangesCompleted: (json['exchangesCompleted'] ?? 0) as int,
      lastAchievementUpdate: json['lastAchievementUpdate'] != null
          ? DateTime.tryParse(json['lastAchievementUpdate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      phone: json['phone']?.toString(),
      profileImagePath: json['profileImagePath'],
      profileImageUrl: json['profileImageUrl'],
      isBlocked: json['isBlocked'] == true,
      blockedById: json['blockedById'],
      blockedByName: json['blockedByName'],
      blockedReason: json['blockedReason'],
      blockedAt: json['blockedAt'] != null
          ? DateTime.tryParse(json['blockedAt'])
          : null,
    );
  }

  SessionUser copyWith({
    String? name,
    String? city,
    DateTime? createdAt,
    String? phone,
    String? profileImagePath,
    String? profileImageUrl,
    bool? isBlocked,
    String? blockedById,
    String? blockedByName,
    String? blockedReason,
    DateTime? blockedAt,
  }) {
    return SessionUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      city: city ?? this.city,
      role: role,
      likes: likes,
      level: level,
      itemsPosted: itemsPosted,
      itemsApproved: itemsApproved,
      exchangesCompleted: exchangesCompleted,
      lastAchievementUpdate: lastAchievementUpdate,
      createdAt: createdAt ?? this.createdAt,
      phone: phone ?? this.phone,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedById: blockedById ?? this.blockedById,
      blockedByName: blockedByName ?? this.blockedByName,
      blockedReason: blockedReason ?? this.blockedReason,
      blockedAt: blockedAt ?? this.blockedAt,
    );
  }
}

