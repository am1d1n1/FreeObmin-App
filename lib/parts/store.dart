part of '../main.dart';

/* ===========================
        NEO STORE
=========================== */

final NeoStore neoStore = NeoStore();
final GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();

class NeoStore extends ChangeNotifier {
  SessionUser? _user;
  SessionUser? get user => _user;

  bool ready = false;

  int selectedThemeIndex = 0;
  int selectedThemeMode = 0;
  ThemeMode get themeMode {
    switch (selectedThemeMode) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      case 2:
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  bool get isDark => themeMode == ThemeMode.dark;

  final List<Item> _items = [];
  List<Item> get items => List.from(_items); // Возвращаем копию списка

  final List<ChatThread> _chats = [];
  List<ChatThread> get chats => List.from(_chats); // Возвращаем копию списка

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.from(_notifications);

  final List<Complaint> _complaints = [];
  List<Complaint> get complaints => List.from(_complaints);

  final List<SessionUser> _users = [];
  List<SessionUser> get users => List.from(_users);

  final Map<String, String?> _profileImageCache = {};

  final Set<String> favorites = {};

  Future<LocationData>? _locationsFuture;

  bool sNotifs = true;
  bool sHaptics = true;
  bool sAutoPlay = true;
  bool sUseNeon = true;
  bool sAutoSync = true;
  bool sSaveHistory = true;
  bool sShowOnlineStatus = true;

  bool _isUserChanging = false;

  // Firebase listeners
  StreamSubscription? _itemsSubscription;
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _complaintsSubscription;
  StreamSubscription? _userDocSubscription;
  StreamSubscription? _usersSubscription;

  // Фільтри
  String _selectedCategory = 'Усі';
  String _selectedCity = 'Усі';
  ItemType? _selectedType;
  String _sortBy = 'newest';
  String _searchQuery = '';

  String get selectedCategory => _selectedCategory;
  String get selectedCity => _selectedCity;
  ItemType? get selectedType => _selectedType;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;

  Future<LocationData> get locations async {
    _locationsFuture ??= LocationData.load();
    return _locationsFuture!;
  }

  // Cache для фильтрованных элементов
  List<Item> _cachedFilteredItems = [];
  DateTime _lastFilterUpdate = DateTime.now();
  final int _feedPageSize = 20;
  int _visibleFeedCount = 20;
  bool _isLoadingMoreFeed = false;

  List<Item> get filteredItems {
    // Используем кэширование для повышения производительности
    final now = DateTime.now();
    if (_cachedFilteredItems.isNotEmpty &&
        now.difference(_lastFilterUpdate).inSeconds < 2) {
      return _cachedFilteredItems;
    }

    List<Item> result = getApprovedItems();

    if (_selectedCategory != 'Усі') {
      result =
          result.where((item) => item.category == _selectedCategory).toList();
    }

    if (_selectedCity != 'Усі') {
      result = result.where((item) => item.city == _selectedCity).toList();
    }

    if (_selectedType != null) {
      result = result.where((item) => item.type == _selectedType).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final tokenGroups = _buildSearchTokenGroups(_searchQuery);
      result = result.where((item) {
        return _matchesSearch(item, tokenGroups);
      }).toList();
    }

    if (_sortBy == 'newest') {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    _cachedFilteredItems = result;
    _lastFilterUpdate = now;
    return result;
  }

  List<Item> get visibleFilteredItems {
    final items = filteredItems;
    if (items.length <= _visibleFeedCount) return items;
    return items.sublist(0, _visibleFeedCount);
  }

  bool get canLoadMoreFeed => filteredItems.length > _visibleFeedCount;

  void resetFeedPagination() {
    _visibleFeedCount = _feedPageSize;
  }

  void loadMoreFeed() {
    if (_isLoadingMoreFeed || !canLoadMoreFeed) return;
    _isLoadingMoreFeed = true;
    _visibleFeedCount += _feedPageSize;
    _isLoadingMoreFeed = false;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    _cachedFilteredItems = [];
    resetFeedPagination();
    notifyListeners();
  }

  static const Map<String, List<String>> _searchSynonyms = {
    'смартфон': ['телефон', 'мобильный', 'мобільний', 'smartphone'],
    'телефон': ['смартфон', 'мобильный', 'мобільний', 'smartphone'],
    'мобила': ['телефон', 'смартфон', 'мобильный', 'мобільний'],
    'ноутбук': ['лэптоп', 'лептоп', 'laptop'],
    'компьютер': ['пк', 'pc', 'desktop', 'комп'],
    'велосипед': ['байк', 'bike'],
    'планшет': ['tablet'],
    'наушники': ['гарнитура', 'headphones'],
    'куртка': ['пуховик', 'ветровка'],
    'кроссовки': ['кеды', 'sneakers'],
    'телевизор': ['тв', 'tv'],
  };

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll('ʼ', "'")
        .replaceAll('’', "'");
  }

  List<List<String>> _buildSearchTokenGroups(String query) {
    final normalized = _normalizeSearchText(query);
    final rawTokens = normalized
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((t) => t.isNotEmpty)
        .toList();
    if (rawTokens.isEmpty) return const [];
    return rawTokens.map((token) {
      final synonyms = _searchSynonyms[token] ?? const [];
      final group = <String>{token};
      for (final synonym in synonyms) {
        group.add(_normalizeSearchText(synonym));
      }
      return group.toList();
    }).toList();
  }

  bool _matchesSearch(Item item, List<List<String>> tokenGroups) {
    if (tokenGroups.isEmpty) return true;
    final fields = [
      _normalizeSearchText(item.title),
      _normalizeSearchText(item.desc),
      _normalizeSearchText(item.category),
      _normalizeSearchText(item.city),
    ];
    for (final group in tokenGroups) {
      var matched = false;
      for (final token in group) {
        if (fields.any((f) => f.contains(token))) {
          matched = true;
          break;
        }
      }
      if (!matched) return false;
    }
    return true;
  }

  bool matchesSearch(Item item, String query) {
    return _matchesSearch(item, _buildSearchTokenGroups(query));
  }

  int searchScore(Item item, String query) {
    final tokenGroups = _buildSearchTokenGroups(query);
    if (tokenGroups.isEmpty) return 0;
    final title = _normalizeSearchText(item.title);
    final desc = _normalizeSearchText(item.desc);
    final category = _normalizeSearchText(item.category);
    final city = _normalizeSearchText(item.city);
    var score = 0;
    for (final group in tokenGroups) {
      if (group.any((t) => title.contains(t))) score += 3;
      if (group.any((t) => category.contains(t))) score += 2;
      if (group.any((t) => desc.contains(t))) score += 1;
      if (group.any((t) => city.contains(t))) score += 1;
    }
    return score;
  }

  List<String> get availableCategories {
    final categories = _items.map((item) => item.category).toSet().toList();
    categories.insert(0, 'Усі');
    return categories;
  }

  List<String> get availableCities {
    final cities = _items.map((item) => item.city).toSet().toList();
    cities.insert(0, 'Усі');
    return cities;
  }

  void setFilters({
    String? category,
    String? city,
    ItemType? type,
    String? sort,
  }) {
    bool changed = false;

    if (category != null && category != _selectedCategory) {
      _selectedCategory = category;
      changed = true;
    }

    if (city != null && city != _selectedCity) {
      _selectedCity = city;
      changed = true;
    }

    if (type != _selectedType) {
      _selectedType = type;
      changed = true;
    }

    if (sort != null && sort != _sortBy) {
      _sortBy = sort;
      changed = true;
    }

    if (changed) {
      // Очищаем кэш фильтров
      _cachedFilteredItems = [];
      resetFeedPagination();
      notifyListeners();
    }
  }

  void clearFilters() {
    bool changed = false;

    if (_selectedCategory != 'Усі') {
      _selectedCategory = 'Усі';
      changed = true;
    }

    if (_selectedCity != 'Усі') {
      _selectedCity = 'Усі';
      changed = true;
    }

    if (_selectedType != null) {
      _selectedType = null;
      changed = true;
    }

    if (_sortBy != 'newest') {
      _sortBy = 'newest';
      changed = true;
    }

    if (changed) {
      // Очищаем кэш фильтров
      _cachedFilteredItems = [];
      resetFeedPagination();
      notifyListeners();
    }
  }

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      selectedThemeIndex = sp.getInt('neo_theme') ?? 0;
      selectedThemeMode = sp.getInt('neo_theme_mode') ?? 0;
      sNotifs = sp.getBool('neo_notifs') ?? true;
      sHaptics = sp.getBool('neo_haptics') ?? true;
      sAutoPlay = sp.getBool('neo_autoplay') ?? true;
      sUseNeon = sp.getBool('neo_neon') ?? true;
      sAutoSync = sp.getBool('neo_auto_sync') ?? true;
      sSaveHistory = sp.getBool('neo_save_history') ?? true;
      sShowOnlineStatus = sp.getBool('neo_show_online') ?? true;

      final fRaw = sp.getString('neo_favs_guest');
      if (fRaw != null) {
        try {
          favorites
            ..clear()
            ..addAll((jsonDecode(fRaw) as List).map((e) => e.toString()));
        } catch (_) {}
      }
      // Загружаем гостевой кэш чатов (если был)
      await _loadChatsCacheForCurrentUser();

      print('🔄 Инициализация Firebase данных...');
      await _initFirebaseListeners();
    } catch (e) {
      print('❌ Помилка инициализации store: $e');
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> _initFirebaseListeners() async {
    try {
      _authSubscription = FirebaseService.auth
          ?.authStateChanges()
          .listen((User? firebaseUser) async {
        if (_isUserChanging) return;
        _isUserChanging = true;

        final previousUserId = _user?.uid ?? '';

        try {
          // Сбрасываем подписку на чаты при смене пользователя
          await _chatsSubscription?.cancel();
          _chatsSubscription = null;
          await _complaintsSubscription?.cancel();
          _complaintsSubscription = null;
          await _userDocSubscription?.cancel();
          _userDocSubscription = null;
          await _usersSubscription?.cancel();
          _usersSubscription = null;
          _users.clear();

          // Всегда чистим чаты в памяти, чтобы не показывать "чужие" данные
          _chats.clear();

          if (firebaseUser != null) {
            if (previousUserId.isNotEmpty && previousUserId != firebaseUser.uid) {
              await _clearOneSignalPlayerId(previousUserId);
              OneSignal.logout();
            }
            // 1) Загружаем профиль пользователя
            await _loadUserFromFirebase(firebaseUser.uid);
            _setupUserDocSubscription(firebaseUser.uid);
            OneSignal.login(firebaseUser.uid);
            await _syncOneSignalPlayerId();
            if (sShowOnlineStatus) {
              await setOnlineStatus(true);
            }

            // 2) Подтягиваем локальные избранное/кэш чатов ТОЛЬКО для этого uid
            await _loadFavsForCurrentUser();
            await _loadChatsCacheForCurrentUser();

            // 3) Подписываемся на чаты конкретного пользователя
            _setupChatsSubscription(firebaseUser.uid);
            _setupNotificationsSubscription(firebaseUser.uid);
            _setupComplaintsSubscription();
            if (_user?.isAdmin == true) {
              _setupUsersSubscription();
            }
          } else {
            // Гостевой режим
            if (sShowOnlineStatus) {
              await setOnlineStatus(false);
            }
            if (previousUserId.isNotEmpty) {
              await _clearOneSignalPlayerId(previousUserId);
            }
            _user = null;
            OneSignal.logout();
            await _saveUser();

            // Загружаем гостевое избранное (если было) и гостевой кэш чатов
            await _loadFavsForCurrentUser();
            await _loadChatsCacheForCurrentUser();
            _notificationsSubscription?.cancel();
            _notifications.clear();
            _complaints.clear();
            _usersSubscription?.cancel();
            _usersSubscription = null;
            _users.clear();
          }
        } catch (e) {
          print('❌ Помилка обработки authStateChanges: $e');
        } finally {
          _isUserChanging = false;
          notifyListeners();
        }
      });

      _itemsSubscription = FirebaseService.firestore
          ?.collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _updateItemsFromSnapshot(snapshot);
      });

      if (_user != null) {
        _chatsSubscription = FirebaseService.firestore
            ?.collection('chats')
            .where('participants', arrayContains: _user!.uid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots()
            .listen((snapshot) {
          _updateChatsFromSnapshot(snapshot);
        });
      }
    } catch (e) {
      print('❌ Помилка инициализации Firebase listeners: $e');
      rethrow;
    }
  }

  void _updateItemsFromSnapshot(QuerySnapshot snapshot) {
    final List<Item> newItems = [];

    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final item = Item.fromJson(data);
        newItems.add(item);
      } catch (e) {
        print('❌ Помилка парсинга item: $e');
      }
    }

    // Обновляем список с уведомлением
    _items.clear();
    _items.addAll(newItems);

    // Очищаем кэш фильтров
    _cachedFilteredItems = [];
    resetFeedPagination();

    // Уведомляем слушателей
    _saveItems();
    notifyListeners();
  }

  void _updateChatsFromSnapshot(QuerySnapshot snapshot) {
    final List<ChatThread> newChats = [];

    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final chat = _chatFromFirebase(data, doc.id);
        newChats.add(chat);
      } catch (e) {
        print('❌ Помилка парсинга чата: $e');
      }
    }

    // Обновляем список с уведомлением
    _chats.clear();
    _chats.addAll(newChats);

    // Уведомляем слушателей
    _saveChats();
    notifyListeners();
  }

  void _setupNotificationsSubscription(String uid) {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = FirebaseService.firestore
        ?.collection('notifications')
        .where('toКористувачId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      final List<AppNotification> list = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        list.add(AppNotification.fromJson(doc.id, data));
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notifications
        ..clear()
        ..addAll(list);
      notifyListeners();
    });
  }

  void _setupComplaintsSubscription() {
    _complaintsSubscription?.cancel();
    final user = _user;
    if (user == null || !user.isModerator) {
      _complaints.clear();
      notifyListeners();
      return;
    }
    _complaintsSubscription = FirebaseService.firestore
        ?.collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _updateComplaintsFromSnapshot(snapshot);
    });
  }

  void _updateComplaintsFromSnapshot(QuerySnapshot snapshot) {
    final List<Complaint> list = [];
    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        list.add(Complaint.fromJson(doc.id, data));
      } catch (e) {
        print('? Помилка парсинга жалобы: $e');
      }
    }
    _complaints
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  void _setupUsersSubscription() {
    _usersSubscription?.cancel();
    final firestore = FirebaseService.firestore;
    if (firestore == null) return;
    _usersSubscription = firestore
        .collection('users')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      _updateUsersFromSnapshot(snapshot);
    });
  }

  void _updateUsersFromSnapshot(QuerySnapshot snapshot) {
    _users
      ..clear()
      ..addAll(snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return _sessionUserFromData(doc.id, data);
      }));
    notifyListeners();
  }

  void _setupUserDocSubscription(String uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = FirebaseService.firestore
        ?.collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      _user = _sessionUserFromData(uid, data);
      if (_user?.isAdmin == true) {
        _setupUsersSubscription();
      } else {
        _usersSubscription?.cancel();
        _usersSubscription = null;
        _users.clear();
      }
      notifyListeners();
    });
  }

  Future<String?> _createNotification({
    required String toUserId,
    required String fromUserId,
    required String fromName,
    required String chatId,
    String itemId = '',
    String action = '',
    String? comment,
    required String title,
    required String body,
  }) async {
    try {
      final doc = FirebaseService.firestore!.collection('notifications').doc();
      await doc.set({
        'toКористувачId': toUserId,
        'fromКористувачId': fromUserId,
        'fromName': fromName,
        'chatId': chatId,
        'itemId': itemId,
        'action': action,
        'comment': comment,
        'title': title,
        'body': body,
        'status': 'pending',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return doc.id;
    } catch (e) {
      print('? Помилка создания уведомления: $e');
      return null;
    }
  }

  Future<void> _updateNotificationStatus(String id, String status) async {
    try {
      await FirebaseService.firestore!
          .collection('notifications')
          .doc(id)
          .update({'status': status});
    } catch (e) {
      print('? Помилка обновления статуса уведомления: $e');
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await FirebaseService.firestore!
          .collection('notifications')
          .doc(id)
          .update({'read': true});
    } catch (e) {
      print('? Помилка отметки уведомления прочитанным: $e');
    }
  }

  Future<void> _loadUserFromFirebase(String uid) async {
    try {
      final doc =
          await FirebaseService.firestore!.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _user = _sessionUserFromData(uid, data);
        _profileImageCache[uid] = _user!.profileImageUrl;
        await _saveUser();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Помилка загрузки пользователя из Firebase: $e');
    }
  }

  SessionUser _sessionUserFromData(String uid, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return SessionUser(
      uid: uid,
      name: data['name'] ?? 'Користувач',
      email: data['email'] ?? 'user@example.com',
      city: data['city'] ?? 'Київ',
      role: data['role'] == 'moderator'
          ? UserRole.moderator
          : data['role'] == 'admin'
              ? UserRole.admin
              : UserRole.user,
      likes: data['likes'] ?? 0,
      level: data['level'] ?? 1,
      itemsPosted: data['itemsPosted'] ?? 0,
      itemsApproved: data['itemsApproved'] ?? 0,
      exchangesCompleted: data['exchangesCompleted'] ?? 0,
      lastAchievementUpdate: data['lastAchievementUpdate'] != null
          ? DateTime.tryParse(data['lastAchievementUpdate'])
          : null,
      createdAt: parseDate(data['createdAt']),
      phone: (data['phone'] ?? data['phoneNumber'])?.toString(),
      profileImagePath: data['profileImagePath'],
      profileImageUrl: data['profileImageUrl'],
      isBlocked: data['isBlocked'] == true,
      blockedById: data['blockedById'],
      blockedByName: data['blockedByName'],
      blockedReason: data['blockedReason'],
      blockedAt: data['blockedAt'] != null
          ? DateTime.tryParse(data['blockedAt'])
          : null,
    );
  }

  Future<String?> fetchUserProfileImageUrl(String uid) async {
    if (uid.isEmpty) return null;
    if (_profileImageCache.containsKey(uid)) {
      final cached = _profileImageCache[uid];
      if (cached?.isNotEmpty == true) return cached;
    }

    try {
      final doc =
          await FirebaseService.firestore!.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final url = data['profileImageUrl'] as String?;
        if (url?.isNotEmpty == true) {
          _profileImageCache[uid] = url;
        } else {
          _profileImageCache.remove(uid);
        }
        return url;
      }
    } catch (e) {
      print('❌ Помилка загрузки фото профілю: $e');
    }

    _profileImageCache.remove(uid);
    return null;
  }

  Future<SessionUser?> fetchUserById(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc =
          await FirebaseService.firestore!.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final user = _sessionUserFromData(uid, data);
      if (user.profileImageUrl?.isNotEmpty == true) {
        _profileImageCache[uid] = user.profileImageUrl;
      }
      return user;
    } catch (e) {
      print('? Помилка отримання користувача: $e');
      return null;
    }
  }

  Future<void> _syncOneSignalPlayerId() async {
    final user = _user;
    if (user == null) return;

    try {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) return;

      await FirebaseService.firestore!
          .collection('users')
          .doc(user.uid)
          .set({'oneSignalId': playerId}, SetOptions(merge: true));
    } catch (e) {
      print('❌ Помилка сохранения OneSignal ID: $e');
    }
  }

  Future<void> _clearOneSignalPlayerId(String uid) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseService.firestore!
          .collection('users')
          .doc(uid)
          .set({'oneSignalId': null}, SetOptions(merge: true));
    } catch (e) {
      print('❌ Failed to clear OneSignal ID: $e');
    }
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final user = _user;
    if (user == null) return;
    try {
      await FirebaseService.firestore!.collection('users').doc(user.uid).set({
        'online': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('? Помилка обновления онлайн статуса: $e');
    }
  }

  Future<bool> _sendPushToUser({
    required String userId,
    required String title,
    required String body,
  }) async {
    if (AppConfig.pushServerUrl.isEmpty) return false;

    try {
      final doc = await FirebaseService.firestore!
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data() ?? {};
      final oneSignalId = data['oneSignalId'] as String?;
      if (oneSignalId == null || oneSignalId.isEmpty) return false;

      final client = HttpClient();
      try {
        final request = await client.postUrl(Uri.parse(AppConfig.pushServerUrl));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({
          'to': oneSignalId,
          'title': title,
          'body': body,
        }));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          print('? Помилка отправки пуша: ${response.statusCode}');
          return false;
        }
        if (responseBody.isNotEmpty) {
          try {
            final payload = jsonDecode(responseBody);
            if (payload is Map && payload['ok'] == true) {
              final raw = payload['response'];
              if (raw is String) {
                try {
                  final inner = jsonDecode(raw);
                  if (inner is Map && inner['errors'] != null) return false;
                } catch (_) {
                  if (raw.contains('errors')) return false;
                }
              } else if (raw is Map && raw['errors'] != null) {
                return false;
              }
            }
          } catch (_) {}
        }
        return true;
      } finally {
        client.close();
      }
    } catch (e) {
      print('? Помилка отправки пуша: $e');
      return false;
    }
  }

  bool canMessageUser(String peerId) {
    final user = _user;
    if (user == null) return false;
    if (!user.isBlocked) return true;
    return user.blockedById != null && user.blockedById == peerId;
  }

  Future<void> setChatUserBlocked({
    required String chatId,
    required String userId,
    required bool blocked,
  }) async {
    final me = _user;
    if (me == null) return;
    if (!me.isModerator) return;

    try {
      final update = blocked
          ? { 'blockedUsers.$userId': true }
          : { 'blockedUsers.$userId': FieldValue.delete() };

      await FirebaseService.firestore!
          .collection('chats')
          .doc(chatId)
          .update(update);

      final index = _chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        final oldChat = _chats[index];
        final updatedBlocked = Set<String>.from(oldChat.blockedUsers);
        if (blocked) {
          updatedBlocked.add(userId);
        } else {
          updatedBlocked.remove(userId);
        }
        final updatedChat = ChatThread(
          id: oldChat.id,
          peerId: oldChat.peerId,
          peerName: oldChat.peerName,
          peerEmail: oldChat.peerEmail,
          messages: oldChat.messages,
          unread: oldChat.unread,
          relatedItemId: oldChat.relatedItemId,
          lastRead: oldChat.lastRead,
          blockedUsers: updatedBlocked,
        );
        _chats[index] = updatedChat;
        await _saveChats();
        notifyListeners();
      }
    } catch (e) {
      print('? Помилка блокування користувача в чаті: $e');
    }
  }

  Future<void> submitComplaint({
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
    String? itemId,
    String? itemTitle,
  }) async {
    final user = _user;
    if (user == null) return;
    if (reportedUserId.isEmpty) return;

    try {
      final doc = FirebaseService.firestore!.collection('complaints').doc();
      await doc.set({
        'reporterId': user.uid,
        'reporterName': user.name,
        'reportedКористувачId': reportedUserId,
        'reportedКористувачName': reportedUserName,
        'reason': reason,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'status': 'open',
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('? Помилка создания жалобы: $e');
    }
  }

  Future<void> resolveComplaint(
    Complaint complaint, {
    required bool accept,
    String? moderatorReason,
  }) async {
    final moderator = _user;
    if (moderator == null || !moderator.isModerator) return;

    try {
      final data = <String, dynamic>{
        'status': accept ? 'accepted' : 'rejected',
        'moderatorId': moderator.uid,
        'moderatorName': moderator.name,
        'resolvedAt': DateTime.now().toIso8601String(),
      };
      await FirebaseService.firestore!
          .collection('complaints')
          .doc(complaint.id)
          .set(data, SetOptions(merge: true));

      if (accept) {
        await setUserBlocked(
          userId: complaint.reportedUserId,
          blocked: true,
          reason: moderatorReason ?? complaint.reason,
        );
      }
    } catch (e) {
      print('? Помилка обработки жалобы: $e');
    }
  }

  Future<void> setUserBlocked({
    required String userId,
    required bool blocked,
    String? reason,
  }) async {
    final moderator = _user;
    if (moderator == null || !moderator.isModerator) return;

    try {
      final update = <String, dynamic>{
        'isBlocked': blocked,
        'blockedById': blocked ? moderator.uid : null,
        'blockedByName': blocked ? moderator.name : null,
        'blockedReason': blocked ? reason : null,
        'blockedAt': blocked ? DateTime.now().toIso8601String() : null,
      };
      await FirebaseService.firestore!
          .collection('users')
          .doc(userId)
          .set(update, SetOptions(merge: true));

      if (_user?.uid == userId) {
        _user = _user!.copyWith(
          isBlocked: blocked,
          blockedById: blocked ? moderator.uid : null,
          blockedByName: blocked ? moderator.name : null,
          blockedReason: blocked ? reason : null,
          blockedAt: blocked ? DateTime.now() : null,
        );
        notifyListeners();
      }
    } catch (e) {
      print('? Помилка обновления блокировки пользователя: $e');
    }
  }

  Future<void> setUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final admin = _user;
    if (admin == null || !admin.isAdmin) return;
    if (admin.uid == userId && role != UserRole.admin) return;

    try {
      final roleValue = role == UserRole.admin
          ? 'admin'
          : role == UserRole.moderator
              ? 'moderator'
              : 'user';
      await FirebaseService.firestore!
          .collection('users')
          .doc(userId)
          .set({'role': roleValue}, SetOptions(merge: true));

      for (var i = 0; i < _users.length; i++) {
        if (_users[i].uid == userId) {
          _users[i] = _sessionUserFromData(userId, {
            'name': _users[i].name,
            'email': _users[i].email,
            'city': _users[i].city,
            'role': roleValue,
            'likes': _users[i].likes,
            'level': _users[i].level,
            'itemsPosted': _users[i].itemsPosted,
            'itemsApproved': _users[i].itemsApproved,
            'exchangesCompleted': _users[i].exchangesCompleted,
            'createdAt': _users[i].createdAt?.toIso8601String(),
            'phone': _users[i].phone,
            'profileImagePath': _users[i].profileImagePath,
            'profileImageUrl': _users[i].profileImageUrl,
            'isBlocked': _users[i].isBlocked,
            'blockedById': _users[i].blockedById,
            'blockedByName': _users[i].blockedByName,
            'blockedReason': _users[i].blockedReason,
            'blockedAt': _users[i].blockedAt?.toIso8601String(),
          });
          break;
        }
      }
      notifyListeners();
    } catch (e) {
      print('? Помилка обновления роли пользователя: $e');
    }
  }

  Future<bool> isUserBlocked(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final doc =
          await FirebaseService.firestore!.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      return data['isBlocked'] == true;
    } catch (e) {
      print('? Помилка проверки блокировки пользователя: $e');
      return false;
    }
  }

  ChatThread _chatFromFirebase(Map<String, dynamic> data, String id) {
    final participants = List<String>.from(data['participants'] ?? []);
    final currentUserId = _user?.uid ?? '';
    final peerId = participants.firstWhere((p) => p != currentUserId);

    DateTime parseMessageTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    final rawLastRead = Map<String, dynamic>.from(data['lastRead'] ?? {});
    final lastRead = <String, DateTime>{};
    rawLastRead.forEach((key, value) {
      if (value == null) return;
      if (value is Timestamp) {
        lastRead[key] = value.toDate();
        return;
      }
      if (value is DateTime) {
        lastRead[key] = value;
        return;
      }
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        lastRead[key] = parsed;
      }
    });

    final blockedUsers = <String>{};
    final rawBlocked = data['blockedUsers'];
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
      id: id,
      peerId: peerId,
      peerName: _peerNameFromChat(data, peerId),
      peerEmail: _peerEmailFromChat(data, peerId),
      messages: (data['messages'] as List? ?? []).map((msg) {
        return ChatMessage(
          id: msg['id'] ?? '',
          text: msg['text'] ?? '',
          fromMe: msg['from'] == currentUserId,
          at: parseMessageTime(msg['at']),
          type: msg['type'] == 'image' ? MessageType.image : MessageType.text,
          imageUrl: msg['imageUrl'],
          itemId: msg['itemId'],
          itemTitle: msg['itemTitle'],
        );
      }).toList(),
      unread: data['unread']?[currentUserId] ?? 0,
      relatedItemId: data['relatedItemId'],
      lastRead: lastRead,
      blockedUsers: blockedUsers,
    );
  }

  String _peerNameFromChat(Map<String, dynamic> data, String peerId) {
    final info = Map<String, dynamic>.from(data['participantsInfo'] ?? {});
    final peer = Map<String, dynamic>.from(info[peerId] ?? {});
    return (peer['name'] as String?) ?? (data['peerName'] as String?) ?? 'Користувач';
  }

  String _peerEmailFromChat(Map<String, dynamic> data, String peerId) {
    final info = Map<String, dynamic>.from(data['participantsInfo'] ?? {});
    final peer = Map<String, dynamic>.from(info[peerId] ?? {});
    return (peer['email'] as String?) ??
        (data['peerEmail'] as String?) ??
        'user@example.com';
  }

  Future<void> _saveUser() async {
    final sp = await SharedPreferences.getInstance();
    if (_user == null) {
      await sp.remove('neo_user');
      return;
    }
    await sp.setString('neo_user', jsonEncode(_user!.toJson()));
  }

  Future<void> _saveItems() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        'neo_items', jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveChats() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _kChats(), jsonEncode(_chats.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveTheme() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('neo_theme', selectedThemeIndex);
    await sp.setInt('neo_theme_mode', selectedThemeMode);
  }

  String _uidOrGuest() => _user?.uid.isNotEmpty == true ? _user!.uid : 'guest';

  String _kFavs() => 'neo_favs_${_uidOrGuest()}';
  String _kChats() => 'neo_chats_${_uidOrGuest()}';

  Future<void> _loadFavsForCurrentUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kFavs());
    favorites.clear();
    if (raw == null) return;
    try {
      favorites.addAll((jsonDecode(raw) as List).map((e) => e.toString()));
    } catch (_) {}
  }

  Future<void> _loadChatsCacheForCurrentUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kChats());
    _chats.clear();
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
          .toList();
      _chats.addAll(list);
    } catch (_) {}
  }

  void _setupChatsSubscription(String uid) {
    _chatsSubscription?.cancel();
    _chatsSubscription = FirebaseService.firestore
        ?.collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _updateChatsFromSnapshot(snapshot);
    });
  }

  Future<void> _saveFavs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kFavs(), jsonEncode(favorites.toList()));
  }

  Future<void> _saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('neo_notifs', sNotifs);
    await sp.setBool('neo_haptics', sHaptics);
    await sp.setBool('neo_autoplay', sAutoPlay);
    await sp.setBool('neo_neon', sUseNeon);
    await sp.setBool('neo_auto_sync', sAutoSync);
    await sp.setBool('neo_save_history', sSaveHistory);
    await sp.setBool('neo_show_online', sShowOnlineStatus);
  }

  void changeTheme(int index) async {
    selectedThemeIndex = index % NeoThemes.themeColors.length;
    await _saveTheme();
    notifyListeners();
  }

  void changeThemeMode(int mode) async {
    selectedThemeMode = mode.clamp(0, 2);
    await _saveTheme();
    notifyListeners();
  }

  bool isFav(String itemId) => favorites.contains(itemId);

  Future<void> toggleFav(String itemId) async {
    final wasFav = favorites.contains(itemId);
    if (wasFav) {
      favorites.remove(itemId);
    } else {
      favorites.add(itemId);
    }
    await _saveFavs();
    notifyListeners();
    await _updateItemLikes(itemId, wasFav ? -1 : 1);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Попытка входа через Firebase...');

      final credential = await FirebaseService.auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Не вдалося отримати користувача після входу.');
      }
      print('? Firebase вход успешен: ${user.uid}');
      await _loadUserFromFirebase(user.uid);
    } on FirebaseAuthException catch (e) {
      print('❌ Помилка Firebase Auth: ${e.code} - ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Невірний пароль.';
          break;
        case 'user-not-found':
          errorMessage = 'Користувача з таким email не знайдено.';
          break;
        case 'user-disabled':
          errorMessage = 'Акаунт вимкнено.';
          break;
        case 'invalid-email':
          errorMessage = 'Невірний формат email.';
          break;
        case 'too-many-requests':
          errorMessage = 'Занадто багато спроб. Спробуйте пізніше.';
          break;
        default:
          errorMessage = 'Помилка входу: ${e.message}';
      }

      if (e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-credentials') {
        errorMessage = 'Невірний email або пароль.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String city,
  }) async {
    try {
      print('🔄 Попытка регистрации через Firebase...');

      final credential =
          await FirebaseService.auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Не вдалося отримати користувача після реєстрації.');
      }
      print('? Firebase регистрация успешна: ${user.uid}');

      await FirebaseService.firestore!.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'city': city,
        'role': 'user',
        'likes': 0,
        'level': 1,
        'itemsPosted': 0,
        'itemsApproved': 0,
        'exchangesCompleted': 0,
        'isBlocked': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _loadUserFromFirebase(user.uid);
    } on FirebaseAuthException catch (e) {
      print('❌ Помилка Firebase Auth при регистрации: ${e.code}');

      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Користувач з таким email вже існує.';
          break;
        case 'weak-password':
          errorMessage =
              'Пароль занадто слабкий. Використовуйте мінімум 6 символів.';
          break;
        case 'invalid-email':
          errorMessage = 'Невірний формат email.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Реєстрація за email вимкнена.';
          break;
        default:
          errorMessage = 'Помилка реєстрації: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_isUserChanging) return;
    _isUserChanging = true;

    try {
      final userId = _user?.uid ?? '';
      if (sShowOnlineStatus) {
        await setOnlineStatus(false);
      }
      if (userId.isNotEmpty) {
        await _clearOneSignalPlayerId(userId);
      }
      await FirebaseService.auth!.signOut();
    } catch (e) {
      print('❌ Помилка выхода из Firebase: $e');
    }

    _user = null;
    await _saveUser();

    _isUserChanging = false;
    notifyListeners();
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    if (_user == null) return false;

    try {
      final user = FirebaseService.auth!.currentUser;
      final credential = EmailAuthProvider.credential(
        email: _user!.email,
        password: currentPassword,
      );

      await user!.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ Помилка смены пароля: ${e.code}');
      return false;
    }
  }

  Future<String?> _uploadProfileImage(String localPath) async {
    return _uploadToCloudinary(
      localPath,
      folder: 'profile_images',
    );
  }

  Future<List<String>> uploadItemImages(
    List<String> imagePaths, {
    ValueChanged<double>? onProgress,
  }) async {
    if (imagePaths.isEmpty) return const [];

    final total = imagePaths.length;
    var completed = 0;
    final uploaded = <String>[];

    for (final path in imagePaths) {
      if (path.startsWith('http')) {
        uploaded.add(path);
        completed += 1;
        if (onProgress != null) {
          onProgress(completed / total);
        }
        continue;
      }

      final url = await _uploadToCloudinary(
        path,
        folder: 'item_images',
        onProgress: onProgress == null
            ? null
            : (value) {
                onProgress((completed + value) / total);
              },
      );
      if (url != null && url.isNotEmpty) {
        uploaded.add(url);
      }
      completed += 1;
      if (onProgress != null) {
        onProgress(completed / total);
      }
    }

    return uploaded;
  }

  Future<void> updateProfile(
      {String? name, String? city, String? profileImagePath}) async {
    if (_user == null) return;

    String? profileImageUrl = _user!.profileImageUrl;

    // Если есть новое изображение, загружаем его в Firebase Storage
    if (profileImagePath != null) {
      profileImageUrl = await _uploadProfileImage(profileImagePath);
    }

    _user = _user!.copyWith(
      name: name ?? _user!.name,
      city: city ?? _user!.city,
      profileImagePath: profileImagePath ?? _user!.profileImagePath,
      profileImageUrl: profileImageUrl ?? _user!.profileImageUrl,
    );

    _profileImageCache[_user!.uid] = _user!.profileImageUrl;

    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (city != null) updateData['city'] = city;
      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }
      if (profileImagePath != null) {
        updateData['profileImagePath'] = profileImagePath;
      }

      await FirebaseService.firestore!
          .collection('users')
          .doc(_user!.uid)
          .update(updateData);
    } catch (e) {
      print('❌ Помилка обновления профілю в Firebase: $e');
    }

    await _saveUser();
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    Item? newItem; // Объявляем переменную здесь

    try {
      final itemData = item.toJson();
      itemData.remove('id');

      final docRef =
          await FirebaseService.firestore!.collection('items').add(itemData);

      newItem = item.copyWith(id: docRef.id); // Присваиваем значение

      // Добавляем локально для мгновенного отображения, без дублей
      final existingIndex = _items.indexWhere((e) => e.id == newItem!.id);
      if (existingIndex == -1) {
        _items.insert(0, newItem);
      } else {
        _items[existingIndex] = newItem;
      }

      // Очищаем кэш фильтров
      _cachedFilteredItems = [];

      // Немедленно уведомляем слушателей
      notifyListeners();

      if (_user != null && item.ownerId == _user!.uid) {
        _user!.itemsPosted++;
        if (item.status == ItemStatus.approved) {
          _user!.itemsApproved++;
        }
        await FirebaseService.firestore!
            .collection('users')
            .doc(_user!.uid)
            .update({
          'itemsPosted': _user!.itemsPosted,
          'itemsApproved': _user!.itemsApproved,
        });
        await _saveUser();
        notifyListeners(); // Еще раз уведомляем об изменении пользователя
      }

      await _saveItems();
    } catch (e) {
      print('❌ Помилка добавления оголошення в Firebase: $e');
      // Откатываем локальные изменения при ошибке
      if (newItem != null) {
        // Проверяем, что newItem не null
        _items.removeWhere((element) => element.id == newItem!.id);
      }
      _cachedFilteredItems = [];
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateItem(Item updatedItem) async {
    final index = _items.indexWhere((e) => e.id == updatedItem.id);
    if (index != -1) {
      final oldItem = _items[index];

      // Если оголошення редактируется пользователем (не модератором),
      // отправляем на повторную модерацию
      if (_user != null &&
          _user!.uid == updatedItem.ownerId &&
          !_user!.isModerator) {
        updatedItem = updatedItem.copyWith(
          status: ItemStatus.pending,
          moderationComment: null,
          updatedAt: DateTime.now(),
        );
      }

      _items[index] = updatedItem;

      // Очищаем кэш фильтров
      _cachedFilteredItems = [];

      // Немедленно уведомляем слушателей
      notifyListeners();

      try {
        await FirebaseService.firestore!
            .collection('items')
            .doc(updatedItem.id)
            .update(updatedItem.toJson());
      } catch (e) {
        print('❌ Помилка обновления оголошення в Firebase: $e');
        // Откатываем изменения при ошибке
        _items[index] = oldItem;
        _cachedFilteredItems = [];
        notifyListeners();
        rethrow;
      }

      await _saveItems();
    }
  }

  Future<void> moderateItem(String itemId, ItemStatus status,
      {String? comment, bool requestChanges = false}) async {
    final index = _items.indexWhere((e) => e.id == itemId);
    if (index != -1) {
      final oldItem = _items[index];
      _items[index] = oldItem.copyWith(
        status: status,
        moderationComment: status == ItemStatus.rejected ? comment : null,
        needsRevision: requestChanges,
      );

      // Очищаем кэш фильтров
      _cachedFilteredItems = [];

      // Немедленно уведомляем слушателей
      notifyListeners();

      if (status == ItemStatus.approved && _user != null) {
        final item = _items[index];
        if (item.ownerId == _user!.uid) {
          _user!.itemsApproved++;
          await _saveUser();
          notifyListeners(); // Уведомляем об изменении пользователя
        }
      }

      try {
        await FirebaseService.firestore!
            .collection('items')
            .doc(itemId)
            .update({
          'status': status == ItemStatus.approved ? 'approved' : 'rejected',
          'moderationComment': status == ItemStatus.rejected ? comment : null,
          'needsRevision': requestChanges,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        final item = _items[index];
        final decisionText = status == ItemStatus.approved
            ? 'Ваше оголошення схвалено'
            : requestChanges
                ? 'Ваше оголошення потребує доопрацювання'
                : 'Ваше оголошення в?дхилено';
        final body = comment?.isNotEmpty == true
            ? '$decisionText: $comment'
            : decisionText;
        final notificationId = await _createNotification(
          toUserId: item.ownerId,
          fromUserId: _user?.uid ?? 'system',
          fromName: 'Модерація',
          chatId: '',
          itemId: item.id,
          action: status == ItemStatus.approved
              ? 'moderation_approved'
              : requestChanges
                  ? 'moderation_revision'
                  : 'moderation_rejected',
          comment: comment,
          title: 'Модерація',
          body: body,
        );
        final sent = await _sendPushToUser(
          userId: item.ownerId,
          title: 'Модерація',
          body: body,
        );
        if (notificationId != null) {
          await _updateNotificationStatus(
              notificationId, sent ? 'sent' : 'failed');
        }
      } catch (e) {
        print('❌ Помилка модерации в Firebase: $e');
        // Откатываем изменения при ошибке
        _items[index] = oldItem;
        _cachedFilteredItems = [];
        notifyListeners();
        rethrow;
      }

      await _saveItems();
    }
  }

  Future<void> deleteItem(String itemId) async {
    final item = _items.firstWhere((e) => e.id == itemId);
    _items.removeWhere((e) => e.id == itemId);
    favorites.remove(itemId);

    // Очищаем кэш фильтров
    _cachedFilteredItems = [];

    // Немедленно уведомляем слушателей
    notifyListeners();

    try {
      await FirebaseService.firestore!.collection('items').doc(itemId).delete();
    } catch (e) {
      print('❌ Помилка удаления оголошення из Firebase: $e');
      // Восстанавливаем при ошибке
      _items.add(item);
      _cachedFilteredItems = [];
      notifyListeners();
      rethrow;
    }

    await _saveItems();
    await _saveFavs();
  }

  List<Item> getApprovedItems() {
    return _items.where((item) => item.status == ItemStatus.approved).toList();
  }

  List<Item> getPendingItems() {
    return _items.where((item) => item.status == ItemStatus.pending).toList();
  }

  List<Item> myItems() {
    final me = _user;
    if (me == null) return [];
    final list = _items.where((e) => e.ownerId == me.uid).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Item> itemsByOwner(String ownerId) {
    final list = _items.where((e) => e.ownerId == ownerId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Item> getSimilarItems(Item item, {int limit = 3}) {
    final query = item.title.toLowerCase();
    return getApprovedItems()
        .where((e) =>
            e.id != item.id &&
            (e.category == item.category ||
                e.city == item.city ||
                e.title.toLowerCase().contains(query) ||
                query.contains(e.title.toLowerCase())))
        .take(limit)
        .toList();
  }

  Future<String> buildShareUrl(Item item) async {
    final slug = _slugifyTitle(item.title);
    final code = await _getOrCreateShortCode(item);
    return 'https://freeobmin.pp.ua/${slug}_$code';
  }

  Future<String> _getOrCreateShortCode(Item item) async {
    final firestore = FirebaseService.firestore;
    if (firestore == null) return item.id;

    try {
      final existing = await firestore
          .collection('short_links')
          .where('itemId', isEqualTo: item.id)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }
    } catch (e) {
      print('? Short link lookup failed: $e');
    }

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(
        6,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      final docRef = firestore.collection('short_links').doc(code);
      final doc = await docRef.get();
      if (doc.exists) {
        continue;
      }
      await docRef.set({
        'itemId': item.id,
        'slug': _slugifyTitle(item.title),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return code;
    }

    return item.id;
  }

  Future<String?> resolveShortCode(String code) async {
    final firestore = FirebaseService.firestore;
    if (firestore == null) return null;
    try {
      final doc = await firestore.collection('short_links').doc(code).get();
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['itemId'] as String?;
    } catch (e) {
      print('? Short link resolve failed: $e');
      return null;
    }
  }

  Future<Item?> fetchItemById(String itemId) async {
    try {
      final existing = _items.firstWhere(
        (e) => e.id == itemId,
        orElse: () => Item(
          id: '',
          title: '',
          desc: '',
          city: '',
          category: '',
          type: ItemType.exchange,
          likes: 0,
          views: 0,
          ownerId: '',
          ownerName: '',
          ownerEmail: '',
          createdAt: DateTime.now(),
          photoPaths: const [],
          photoUrls: const [],
        ),
      );
      if (existing.id.isNotEmpty) {
        return existing;
      }
      final doc = await FirebaseService.firestore
          ?.collection('items')
          .doc(itemId)
          .get();
      if (doc == null || !doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Item.fromJson(data);
    } catch (e) {
      print('? Помилка загрузки item $itemId: $e');
      return null;
    }
  }

  Future<void> incrementViews(String itemId) async {
    final index = _items.indexWhere((e) => e.id == itemId);
    if (index == -1) return;

    final oldItem = _items[index];
    final meId = _user?.uid;
    final sp = await SharedPreferences.getInstance();
    final viewedKey = 'neo_viewed_items_${meId ?? 'guest'}';
    final raw = sp.getString(viewedKey);
    final viewed = raw != null
        ? (jsonDecode(raw) as List).map((e) => e.toString()).toSet()
        : <String>{};

    if (viewed.contains(itemId)) return;
    viewed.add(itemId);
    await sp.setString(viewedKey, jsonEncode(viewed.toList()));

    bool didIncrement = false;

    try {
      if (meId != null) {
        final docRef =
            FirebaseService.firestore!.collection('items').doc(itemId);
        didIncrement =
            await FirebaseService.firestore!.runTransaction<bool>((tx) async {
          final snap = await tx.get(docRef);
          final data = snap.data() ?? {};
          final viewedBy = List<String>.from(data['viewedBy'] ?? []);
          if (viewedBy.contains(meId)) return false;
          final currentViews = (data['views'] ?? oldItem.views) as int;
          tx.update(docRef, {
            'views': currentViews + 1,
            'viewedBy': FieldValue.arrayUnion([meId]),
          });
          return true;
        });
      } else {
        await FirebaseService.firestore!
            .collection('items')
            .doc(itemId)
            .update({'views': FieldValue.increment(1)});
        didIncrement = true;
      }
    } catch (e) {
      print('❌ Помилка обновления просмотров: $e');
    }

    if (!didIncrement) return;

    final newItem = oldItem.copyWith(views: oldItem.views + 1);
    _items[index] = newItem;
    _cachedFilteredItems = [];
    notifyListeners();
    _saveItems();
  }

  Future<void> setActiveViewer(String itemId, bool active) async {
    final uid = _user?.uid;
    if (uid == null) return;

    try {
      final docRef = FirebaseService.firestore!.collection('items').doc(itemId);
      if (active) {
        await docRef.update({
          'activeViewers': FieldValue.arrayUnion([uid]),
          'activeViewersUpdatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        await docRef.update({
          'activeViewers': FieldValue.arrayRemove([uid]),
        });
      }
    } catch (e) {
      print('❌ Помилка обновления активных просмотров: $e');
    }
  }

  Future<void> incrementLikes(String itemId) async {
    await _updateItemLikes(itemId, 1);
  }

  Future<void> _updateItemLikes(String itemId, int delta) async {
    final index = _items.indexWhere((e) => e.id == itemId);
    if (index == -1) return;

    final oldItem = _items[index];
    final newLikes = max(0, oldItem.likes + delta);
    final newItem = oldItem.copyWith(likes: newLikes);
    _items[index] = newItem;

    _cachedFilteredItems = [];
    notifyListeners();

    try {
      await FirebaseService.firestore!
          .collection('items')
          .doc(itemId)
          .update({'likes': newItem.likes});
    } catch (e) {
      print('❌ Помилка обновления лайков: $e');
      _items[index] = oldItem;
      _cachedFilteredItems = [];
      notifyListeners();
    }

    _saveItems();
  }

  int get totalUnread => _chats.fold<int>(0, (a, b) => a + max(0, b.unread));
  int get totalUnreadNotifications =>
      _notifications.where((n) => !n.read).length;

  Future<void> markChatRead(String chatId) async {
    final index = _chats.indexWhere((e) => e.id == chatId);
    if (index != -1) {
      final oldChat = _chats[index];
      final me = _user;
      if (me == null) return;
      final now = DateTime.now();
      final updatedLastRead = Map<String, DateTime>.from(oldChat.lastRead);
      updatedLastRead[me.uid] = now;
      final newChat = ChatThread(
        id: oldChat.id,
        peerId: oldChat.peerId,
        peerName: oldChat.peerName,
        peerEmail: oldChat.peerEmail,
        messages: oldChat.messages,
        unread: 0,
        relatedItemId: oldChat.relatedItemId,
        lastRead: updatedLastRead,
        blockedUsers: oldChat.blockedUsers,
      );

      _chats[index] = newChat;

      // Немедленно уведомляем слушателей
      notifyListeners();

      try {
        await FirebaseService.firestore!
            .collection('chats')
            .doc(chatId)
            .update({
          'unread.${me.uid}': 0,
          'lastRead.${me.uid}': now.toIso8601String(),
        });
      } catch (e) {
        print('❌ Помилка отметки чата прочитанным в Firebase: $e');
        // Откатываем изменения при ошибке
        _chats[index] = oldChat;
        notifyListeners();
        rethrow;
      }

      await _saveChats();
    }
  }

  String _threadId(String meId, String peerId) {
    final a = meId.compareTo(peerId) <= 0 ? meId : peerId;
    final b = meId.compareTo(peerId) <= 0 ? peerId : meId;
    return 't_${a}_$b';
  }

  Future<String> ensureChatWith({
    required String peerId,
    required String peerName,
    required String peerEmail,
    String? itemId,
    String? itemTitle,
  }) async {
    final me = _user;
    if (me == null) throw StateError('Not logged in');

    // IMPORTANT:
    // Firestore запрещает использовать 'array-contains' (и/или array-contains-any) более одного раза в одном запросе.
    // Ранее здесь выполнялась проверка существующего чата через query по participants, что у некоторых пользователей
    // приводило к падению с:
    // "!hasArrayContains: You cannot use 'array-contains' filters more than once."
    //
    // Решение: детерминированный id чата для пары пользователей.
    // Тогда существование чата проверяется через .doc(id).get(), без каких-либо array-contains фильтров.
    final threadId = _threadId(me.uid, peerId);

    try {
      final docRef =
          FirebaseService.firestore!.collection('chats').doc(threadId);
      final snap = await docRef.get();

      if (snap.exists) {
        // При необходимости дополняем participantsInfo, чтобы корректно показывать peerName/peerEmail у обеих сторон.
        final data = snap.data() ?? {};
        final participantsInfo =
            Map<String, dynamic>.from(data['participantsInfo'] ?? {});
        final shouldPatch = !(participantsInfo.containsKey(me.uid) &&
            participantsInfo.containsKey(peerId));

        if (shouldPatch) {
          await docRef.set({
            'participants': [me.uid, peerId],
            'participantsInfo': {
              me.uid: {'name': me.name, 'email': me.email},
              peerId: {'name': peerName, 'email': peerEmail},
            },
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
        return threadId;
      }

      // Если чат не найден — создаем новый (с фиксированным id).
      final createdAt = DateTime.now();
      final firstMessageId = 'm_${createdAt.millisecondsSinceEpoch}';

      final chatData = <String, dynamic>{
        'participants': [me.uid, peerId],
        'participantsInfo': {
          me.uid: {'name': me.name, 'email': me.email},
          peerId: {'name': peerName, 'email': peerEmail},
        },
        // Для совместимости со старым парсером (используется как fallback).
        'peerName': peerName,
        'peerEmail': peerEmail,
        'messages': [
          {
            'id': firstMessageId,
            'text': 'Привіт! Пишу щодо оголошення.',
            'from': me.uid,
            'at': createdAt.toIso8601String(),
            'type': 'text',
            'itemId': itemId,
            'itemTitle': itemTitle,
          }
        ],
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': createdAt.toIso8601String(),
        'lastMessage': 'Привіт! Пишу щодо оголошення.',
        // unread — словарь счетчиков по uid
        'unread': {me.uid: 0, peerId: 1},
        'lastRead': {me.uid: createdAt.toIso8601String()},
        'relatedItemId': itemId,
        'blockedUsers': {},
      };

      await docRef.set(chatData);

      final newChat = ChatThread(
        id: threadId,
        peerId: peerId,
        peerName: peerName,
        peerEmail: peerEmail,
        messages: [
          ChatMessage(
            id: firstMessageId,
            text: 'Привіт! Пишу щодо оголошення.',
            fromMe: true,
            at: createdAt,
            itemId: itemId,
            itemTitle: itemTitle,
          ),
        ],
        unread: 0,
        relatedItemId: itemId,
        lastRead: {me.uid: createdAt},
        blockedUsers: <String>{},
      );

      _chats.insert(0, newChat);
      await _saveChats();
      notifyListeners();

      return threadId;
    } catch (e) {
      print('❌ Помилка создания чата в Firebase: $e');
      rethrow;
    }
  }

  Future<void> sendMessage(String chatId, String text,
      {String? itemId, String? itemTitle}) async {
    final index = _chats.indexWhere((e) => e.id == chatId);
    if (index != -1) {
      final me = _user;
      if (me == null) return;

      final oldChat = _chats[index];
      if (oldChat.blockedUsers.contains(me.uid)) return;

      final newMessage = ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        text: text.trim(),
        fromMe: true,
        at: DateTime.now(),
        itemId: itemId,
        itemTitle: itemTitle,
      );

      final updatedMessages = List<ChatMessage>.from(oldChat.messages)
        ..add(newMessage);

      final updatedChat = ChatThread(
        id: oldChat.id,
        peerId: oldChat.peerId,
        peerName: oldChat.peerName,
        peerEmail: oldChat.peerEmail,
        messages: updatedMessages,
        unread: oldChat.unread,
        relatedItemId: oldChat.relatedItemId,
        lastRead: oldChat.lastRead,
        blockedUsers: oldChat.blockedUsers,
      );

      _chats.removeAt(index);
      _chats.insert(0, updatedChat);

      // Немедленно уведомляем слушателей
      notifyListeners();

      try {
        await FirebaseService.firestore!
            .collection('chats')
            .doc(chatId)
            .update({
          'messages': FieldValue.arrayUnion([
            {
              'id': newMessage.id,
              'text': newMessage.text,
              'from': me.uid,
              'at': newMessage.at.toIso8601String(),
              'type': 'text',
              'itemId': itemId,
              'itemTitle': itemTitle,
            }
          ]),
          'lastMessageAt': newMessage.at.toIso8601String(),
          'lastMessage': text,
          'unread.${oldChat.peerId}': FieldValue.increment(1),
        });

        await _saveChats();
        final notificationId = await _createNotification(
          toUserId: oldChat.peerId,
          fromUserId: me.uid,
          fromName: me.name,
          chatId: chatId,
          title: 'Нове повідомлення',
          body: text,
        );
        final sent = await _sendPushToUser(
          userId: oldChat.peerId,
          title: 'Нове повідомлення',
          body: text,
        );
        if (notificationId != null) {
          await _updateNotificationStatus(
              notificationId, sent ? 'sent' : 'failed');
        }
      } catch (e) {
        print('❌ Помилка отправки сообщения в Firebase: $e');
        // Откатываем изменения при ошибке
        _chats.removeWhere((c) => c.id == chatId);
        _chats.add(oldChat);
        _chats.sort((a, b) => b.last.at.compareTo(a.last.at));
        await _saveChats();
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<String?> _uploadChatImage(String localPath, String chatId,
      {ValueChanged<double>? onProgress}) async {
    return _uploadToCloudinary(
      localPath,
      folder: 'chat_images',
      onProgress: onProgress,
    );
  }

  String _cloudinaryContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String?> _uploadToCloudinary(
    String localPath, {
    String? folder,
    ValueChanged<double>? onProgress,
  }) async {
    if (AppConfig.cloudinaryCloudName.isEmpty || AppConfig.cloudinaryUploadPreset.isEmpty) {
      print('? Cloudinary настройки не заданы');
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final totalBytes = await file.length();

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload');
      final boundary = '----freeobmin_${DateTime.now().millisecondsSinceEpoch}';
      final request = await HttpClient().postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      void writeField(String name, String value) {
        request.add(utf8.encode('--$boundary\r\n'));
        request.add(utf8
            .encode('Content-Disposition: form-data; name="${name}"\r\n\r\n'));
        request.add(utf8.encode('$value\r\n'));
      }

      writeField('upload_preset', AppConfig.cloudinaryUploadPreset);
      if (folder != null && folder.isNotEmpty) {
        writeField('folder', folder);
      }

      final fileName = localPath.split(Platform.pathSeparator).last;
      request.add(utf8.encode('--$boundary\r\n'));
      request.add(utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n'));
      request.add(utf8.encode(
          'Content-Type: ${_cloudinaryContentType(localPath)}\r\n\r\n'));

      int sent = 0;
      await for (final chunk in file.openRead()) {
        request.add(chunk);
        sent += chunk.length;
        if (onProgress != null && totalBytes > 0) {
          onProgress((sent / totalBytes).clamp(0.0, 1.0));
        }
      }
      request.add(utf8.encode('\r\n--$boundary--\r\n'));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('? Cloudinary upload failed: ${response.statusCode} $body');
        return null;
      }
      final payload = jsonDecode(body) as Map<String, dynamic>;
      return (payload['secure_url'] ?? payload['url'])?.toString();
    } catch (e) {
      print('? Помилка загрузки в Cloudinary: $e');
      return null;
    }
  }

  Future<void> sendImageMessage(String chatId, String imagePath,
      {String? itemId,
      String? itemTitle,
      ValueChanged<double>? onProgress}) async {
    final index = _chats.indexWhere((e) => e.id == chatId);
    if (index == -1) return;

    final me = _user;
    if (me == null) return;

    final oldChat = _chats[index];
    if (oldChat.blockedUsers.contains(me.uid)) return;

    final imageUrl =
        await _uploadChatImage(imagePath, chatId, onProgress: onProgress);
    if (imageUrl == null) {
      throw Exception('Не вдалося загрузить фото');
    }

    final newMessage = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      fromMe: true,
      at: DateTime.now(),
      type: MessageType.image,
      imageUrl: imageUrl,
      itemId: itemId,
      itemTitle: itemTitle,
    );

    final updatedMessages = List<ChatMessage>.from(oldChat.messages)
      ..add(newMessage);

    final updatedChat = ChatThread(
      id: oldChat.id,
      peerId: oldChat.peerId,
      peerName: oldChat.peerName,
      peerEmail: oldChat.peerEmail,
      messages: updatedMessages,
      unread: oldChat.unread,
      relatedItemId: oldChat.relatedItemId,
      lastRead: oldChat.lastRead,
      blockedUsers: oldChat.blockedUsers,
    );

    _chats.removeAt(index);
    _chats.insert(0, updatedChat);
    notifyListeners();

    try {
      await FirebaseService.firestore!.collection('chats').doc(chatId).update({
        'messages': FieldValue.arrayUnion([
          {
            'id': newMessage.id,
            'text': '',
            'from': me.uid,
            'at': newMessage.at.toIso8601String(),
            'type': 'image',
            'imageUrl': imageUrl,
            'itemId': itemId,
            'itemTitle': itemTitle,
          }
        ]),
        'lastMessageAt': newMessage.at.toIso8601String(),
        'lastMessage': 'Фото',
        'unread.${oldChat.peerId}': FieldValue.increment(1),
      });

      await _saveChats();
      final notificationId = await _createNotification(
        toUserId: oldChat.peerId,
        fromUserId: me.uid,
        fromName: me.name,
        chatId: chatId,
        title: 'Нове повідомлення',
        body: 'Фото',
      );
      final sent = await _sendPushToUser(
        userId: oldChat.peerId,
        title: 'Нове повідомлення',
        body: 'Фото',
      );
      if (notificationId != null) {
        await _updateNotificationStatus(
            notificationId, sent ? 'sent' : 'failed');
      }
    } catch (e) {
      print('❌ Помилка отправки фото в чат: $e');
      _chats.removeWhere((c) => c.id == chatId);
      _chats.add(oldChat);
      _chats.sort((a, b) => b.last.at.compareTo(a.last.at));
      await _saveChats();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setSettings({
    bool? notifs,
    bool? haptics,
    bool? autoplay,
    bool? neon,
    bool? autoSync,
    bool? saveHistory,
    bool? showOnlineStatus,
  }) async {
    if (notifs != null) sNotifs = notifs;
    if (haptics != null) sHaptics = haptics;
    if (autoplay != null) sAutoPlay = autoplay;
    if (neon != null) sUseNeon = neon;
    if (autoSync != null) sAutoSync = autoSync;
    if (saveHistory != null) sSaveHistory = saveHistory;
    if (showOnlineStatus != null) sShowOnlineStatus = showOnlineStatus;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> resetData() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('neo_items');
    await sp.remove('neo_chats_guest');
    await sp.remove('neo_favs_guest');
    // Также очищаем данные текущего пользователя (если есть)
    await sp.remove(_kChats());
    await sp.remove(_kFavs());
    _items.clear();
    _chats.clear();
    favorites.clear();

    // Очищаем кэш фильтров
    _cachedFilteredItems = [];

    await _saveItems();
    await _saveChats();
    await _saveFavs();
    notifyListeners();
  }

  List<Achievement> getUserAchievements() {
    if (_user == null) return [];

    final achievements = [
      Achievement(
        id: 'novice',
        title: 'Новичок обмена',
        description: 'Створіть перше оголошення',
        icon: Icons.star_outline_rounded,
        color: Colors.blue,
        progress: _user!.itemsPosted,
        target: 1,
        unlocked: _user!.itemsPosted >= 1,
      ),
      Achievement(
        id: 'collector',
        title: 'Коллекционер',
        description: 'Створіть 5 оголошень',
        icon: Icons.collections_rounded,
        color: Colors.purple,
        progress: _user!.itemsPosted,
        target: 5,
        unlocked: _user!.itemsPosted >= 5,
      ),
      Achievement(
        id: 'popular',
        title: 'Популярний',
        description: 'Отримайте 10 вподобань на оголошеннях',
        icon: Icons.favorite_rounded,
        color: Colors.red,
        progress: _user!.likes,
        target: 10,
        unlocked: _user!.likes >= 10,
      ),
      Achievement(
        id: 'approved_master',
        title: 'Мастер одобрений',
        description: 'Отримайте 3 схвалені оголошення',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        progress: _user!.itemsApproved,
        target: 3,
        unlocked: _user!.itemsApproved >= 3,
      ),
      Achievement(
        id: 'trader',
        title: 'Трейдер',
        description: 'Завершите 1 обмен',
        icon: Icons.swap_horiz_rounded,
        color: Colors.orange,
        progress: _user!.exchangesCompleted,
        target: 1,
        unlocked: _user!.exchangesCompleted >= 1,
      ),
      Achievement(
        id: 'expert',
        title: 'Експерт обміну',
        description: 'Завершите 5 обменов',
        icon: Icons.verified_rounded,
        color: Colors.deepPurple,
        progress: _user!.exchangesCompleted,
        target: 5,
        unlocked: _user!.exchangesCompleted >= 5,
      ),
      Achievement(
        id: 'socializer',
        title: 'Товариський',
        description: 'Надішліть 50 повідомлень у чатах',
        icon: Icons.chat_rounded,
        color: Colors.teal,
        progress: _user!.exchangesCompleted * 10,
        target: 50,
        unlocked: _user!.exchangesCompleted >= 5,
      ),
    ];

    return achievements;
  }

  int get unlockedAchievementsCount {
    return getUserAchievements().where((a) => a.unlocked).length;
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _chatsSubscription?.cancel();
    _authSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _complaintsSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}


