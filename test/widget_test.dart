import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AuraMarketApp());
}

// --- МОДЕЛІ ДАНИХ ---
class AuraItem {
  final String id, title, owner, story, location, category;
  final List<dynamic> images;
  final bool isGift;
  bool isFavorite;

  AuraItem({
    required this.id,
    required this.title,
    required this.owner,
    required this.story,
    required this.location,
    required this.category,
    required this.images,
    required this.isGift,
    this.isFavorite = false,
  });
}

class Message {
  final String text;
  final bool isMe;
  final DateTime time;
  Message({required this.text, required this.isMe, required this.time});
}

// --- ГОЛОВНИЙ ДОДАТОК ---
class AuraMarketApp extends StatefulWidget {
  const AuraMarketApp({super.key});
  @override
  State<AuraMarketApp> createState() => _AuraMarketAppState();
}

class _AuraMarketAppState extends State<AuraMarketApp> {
  bool _isDark = true;
  bool _isLoggedIn = true; // Для тестів ставимо true
  String _userName = "Артем";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF818CF8),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: MainNavigation(
        isDark: _isDark,
        isLoggedIn: _isLoggedIn,
        userName: _userName,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
        onUpdateName: (name) => setState(() => _userName = name),
        onLogout: () => setState(() => _isLoggedIn = false),
      ),
    );
  }
}

// --- НАВІГАЦІЯ ТА ЛОГІКА ---
class MainNavigation extends StatefulWidget {
  final bool isDark, isLoggedIn;
  final String userName;
  final VoidCallback onToggleTheme, onLogout;
  final Function(String) onUpdateName;

  const MainNavigation({
    super.key,
    required this.isDark,
    required this.isLoggedIn,
    required this.userName,
    required this.onToggleTheme,
    required this.onUpdateName,
    required this.onLogout,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _tab = 0;
  String _searchQuery = "";

  final List<AuraItem> _items = [
    AuraItem(
      id: "1",
      title: "Старий програвач",
      owner: "Дмитро",
      location: "Київ",
      category: "Ретро",
      story: "Працює, але потребує нової голки. Віддам тому, хто цінує вініл.",
      isGift: true,
      images: ["https://picsum.photos/800/1000?random=1"],
    ),
    AuraItem(
      id: "2",
      title: "Набір фарб",
      owner: "Анна",
      location: "Львів",
      category: "Творчість",
      story: "Майже нові акрилові фарби. Обміняю на пензлі.",
      isGift: false,
      images: ["https://picsum.photos/800/1000?random=2"],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items
        .where(
          (i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    Widget currentBody;
    if (!widget.isLoggedIn && _tab >= 2) {
      currentBody = _buildAuthPlaceholder();
    } else {
      currentBody = IndexedStack(
        index: _tab,
        children: [
          _buildFeed(filteredItems),
          _buildFavorites(),
          AddScreen(
            onAdd: (item) {
              setState(() {
                _items.insert(0, item);
                _tab = 0;
              });
            },
          ),
          const ChatListScreen(),
          ProfileScreen(
            userName: widget.userName,
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
            onUpdateName: widget.onUpdateName,
            onLogout: widget.onLogout,
          ),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          if (widget.isDark) _buildDarkBackground(),
          SafeArea(child: currentBody),
          _buildBottomNavbar(),
        ],
      ),
    );
  }

  Widget _buildDarkBackground() => Positioned.fill(
    child: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.8, -0.5),
          radius: 1.5,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        ),
      ),
    ),
  );

  Widget _buildFeed(List<AuraItem> items) => Column(
    children: [
      _buildSearchHeader(),
      Expanded(
        child: items.isEmpty
            ? const Center(child: Text("Нічого не знайдено"))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: items.length,
                itemBuilder: (context, i) => _FeedCard(
                  item: items[i],
                  onFavorite: () => setState(
                    () => items[i].isFavorite = !items[i].isFavorite,
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _buildSearchHeader() => Padding(
    padding: const EdgeInsets.all(20),
    child: TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: const InputDecoration(
        hintText: "Пошук в Аурі...",
        prefixIcon: Icon(Icons.search_rounded),
      ),
    ),
  );

  Widget _buildFavorites() {
    final favs = _items.where((i) => i.isFavorite).toList();
    return favs.isEmpty
        ? const Center(child: Text("Список обраного порожній"))
        : _buildFeed(favs);
  }

  Widget _buildAuthPlaceholder() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 80, color: Colors.grey),
        const SizedBox(height: 20),
        const Text("Потрібна авторизація"),
        ElevatedButton(onPressed: () {}, child: const Text("Увійти")),
      ],
    ),
  );

  Widget _buildBottomNavbar() => Positioned(
    bottom: 20,
    left: 20,
    right: 20,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navBtn(0, Icons.grid_view_rounded),
              _navBtn(1, Icons.favorite_rounded),
              _addCenterBtn(),
              _navBtn(3, Icons.chat_bubble_rounded),
              _navBtn(4, Icons.person_rounded),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _navBtn(int i, IconData icon) => IconButton(
    icon: Icon(icon, color: _tab == i ? const Color(0xFF6366F1) : Colors.grey),
    onPressed: () => setState(() => _tab = i),
  );

  Widget _addCenterBtn() => GestureDetector(
    onTap: () => setState(() => _tab = 2),
    child: Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        ),
      ),
      child: const Icon(Icons.add, color: Colors.white),
    ),
  );
}

// --- КАРТКА ТОВАРУ ---
class _FeedCard extends StatelessWidget {
  final AuraItem item;
  final VoidCallback onFavorite;
  const _FeedCard({required this.item, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
      ),
      child: Container(
        height: 400,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          image: DecorationImage(
            image: item.images[0].toString().contains('http')
                ? NetworkImage(item.images[0])
                : FileImage(item.images[0] as File) as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 25,
              left: 25,
              right: 25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _categoryTag(item.category),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${item.owner} • ${item.location}",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: item.isFavorite ? Colors.redAccent : Colors.white,
                  size: 30,
                ),
                onPressed: onFavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// --- ЕКРАН ДЕТАЛЕЙ ---
class DetailScreen extends StatelessWidget {
  final AuraItem item;
  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 500,
                flexibleSpace: FlexibleSpaceBar(
                  background: item.images[0].toString().contains('http')
                      ? Image.network(item.images[0], fit: BoxFit.cover)
                      : Image.file(item.images[0] as File, fit: BoxFit.cover),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_pin,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.owner,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.location_on,
                            color: Colors.grey,
                            size: 18,
                          ),
                          Text(
                            item.location,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 40),
                      const Text(
                        "Історія речі",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.story,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                minimumSize: const Size(double.infinity, 65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(userName: item.owner),
                ),
              ),
              child: const Text(
                "НАПИСАТИ ВЛАСНИКУ",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- ЕКРАН ДОДАВАННЯ ---
class AddScreen extends StatefulWidget {
  final Function(AuraItem) onAdd;
  const AddScreen({super.key, required this.onAdd});
  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _loc = TextEditingController();
  File? _image;
  String _category = "Різне";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Нова Аура",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10),
              ),
              child: _image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 50),
                        Text("Додати фото"),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: "Назва"),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _story,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "Розкажіть історію речі...",
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _loc,
            decoration: const InputDecoration(hintText: "Ваше місто"),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(double.infinity, 60),
            ),
            onPressed: () {
              if (_title.text.isNotEmpty && _image != null) {
                widget.onAdd(
                  AuraItem(
                    id: DateTime.now().toString(),
                    title: _title.text,
                    owner: "Ви",
                    story: _story.text,
                    location: _loc.text,
                    category: _category,
                    images: [_image],
                    isGift: true,
                  ),
                );
              }
            },
            child: const Text(
              "ОПУБЛІКУВАТИ",
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// --- ЕКРАН ЧАТУ ---
class ChatScreen extends StatefulWidget {
  final String userName;
  const ChatScreen({super.key, required this.userName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final List<Message> _messages = [];

  void _send() {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _messages.insert(
        0,
        Message(text: _ctrl.text, isMe: true, time: DateTime.now()),
      );
      _ctrl.clear();
    });
    // Імітація відповіді
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(
          () => _messages.insert(
            0,
            Message(
              text: "Привіт! Річ ще є?",
              isMe: false,
              time: DateTime.now(),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message m) => Align(
    alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: m.isMe ? const Color(0xFF6366F1) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(m.text),
    ),
  );

  Widget _buildInput() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(hintText: "Напишіть щось..."),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          backgroundColor: const Color(0xFF6366F1),
          child: IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

// --- ПРОФІЛЬ ---
class ProfileScreen extends StatelessWidget {
  final String userName;
  final bool isDark;
  final VoidCallback onToggleTheme, onLogout;
  final Function(String) onUpdateName;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.isDark,
    required this.onToggleTheme,
    required this.onUpdateName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(25),
      children: [
        const Center(
          child: CircleAvatar(radius: 60, child: Icon(Icons.person, size: 50)),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            userName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),
        _profileOption(Icons.edit, "Змінити ім'я", () {
          final ctrl = TextEditingController(text: userName);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Редагувати ім'я"),
              content: TextField(controller: ctrl),
              actions: [
                TextButton(
                  onPressed: () {
                    onUpdateName(ctrl.text);
                    Navigator.pop(context);
                  },
                  child: const Text("Зберегти"),
                ),
              ],
            ),
          );
        }),
        _profileOption(
          isDark ? Icons.light_mode : Icons.dark_mode,
          "Змінити тему",
          onToggleTheme,
        ),
        _profileOption(
          Icons.logout,
          "Вийти",
          onLogout,
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _profileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: TextStyle(color: color)),
    onTap: onTap,
  );
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Немає активних чатів"));
}
