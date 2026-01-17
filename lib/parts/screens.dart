part of '../main.dart';

class NeoRoot extends StatefulWidget {
  const NeoRoot({super.key});

  @override
  State<NeoRoot> createState() => _NeoRootState();
}

class _NeoRootState extends State<NeoRoot>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  String? _pendingItemId;
  String? _pendingShortCode;
  bool _welcomeShownThisSession = false;
  final GitHubUpdateService _updateService = GitHubUpdateService();
  bool _startupUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await neoStore.init();
      if (mounted) {
        await _showWelcomeIfNeeded();
        _controller.forward();
        await _checkForUpdatesOnStart();
        final pending = _pendingItemId;
        if (pending != null) {
          _pendingItemId = null;
          _openItemFromLink(pending);
        }
        final pendingCode = _pendingShortCode;
        if (pendingCode != null) {
          _pendingShortCode = null;
          _openItemFromShortCode(pendingCode);
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleIncomingLink(initial);
      }
    } catch (e) {
      print('? Помилка initial deep link: $e');
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (error) => print('? Помилка deep link: $error'),
    );
  }

  void _handleIncomingLink(Uri uri) {
    final itemId = _extractItemIdFromUri(uri);
    if (itemId != null) {
      if (!neoStore.ready) {
        _pendingItemId = itemId;
        return;
      }
      _openItemFromLink(itemId);
      return;
    }

    final shortCode = _extractShortCodeFromUri(uri);
    if (shortCode == null) return;
    if (!neoStore.ready) {
      _pendingShortCode = shortCode;
      return;
    }
    _openItemFromShortCode(shortCode);
  }

  void _openItemFromLink(String itemId) {
    final nav = _rootNavKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (context) => NeoItemDetailPage(
          itemId: itemId,
        ),
      ),
    );
  }

  Future<void> _openItemFromShortCode(String code) async {
    final nav = _rootNavKey.currentState;
    if (nav == null) return;
    final itemId = await neoStore.resolveShortCode(code);
    if (itemId == null || itemId.isEmpty) {
      print('? Short link not found: $code');
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (context) => NeoItemDetailPage(
          itemId: itemId,
        ),
      ),
    );
  }

  Future<void> _showWelcomeIfNeeded() async {
    if (_welcomeShownThisSession) return;
    if (!mounted) return;
    _welcomeShownThisSession = true;

    await showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Ласкаво просимо до FreeObmin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'FreeObmin створено, щоб допомогти людям у складний період для країни. Тут усе безкоштовно: діліться речами, знаходьте потрібне та підтримуйте одне одного.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ми віримо в силу спільноти: чим більше добрих обмінів, тим тепліше стає всім.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(160),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Дякуємо, що ви з нами. Бережіть себе та своїх близьких.',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(150),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Почати'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkForUpdatesOnStart() async {
    if (_startupUpdateChecked) return;
    _startupUpdateChecked = true;

    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) return;
      if (result.updateAvailable) {
        await _showUpdateDialogOnStart(result);
      }
    } catch (_) {
      // Ignore auto-check errors on startup.
    }
  }

  Future<void> _showUpdateDialogOnStart(UpdateCheckResult result) {
    final notes = result.releaseNotes.trim();
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Оновлення'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Поточна верс?я: ${result.currentVersion}'),
              Text('Остання верс?я: ${result.latestVersion}'),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Опис рел?зу:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(180),
                    fontSize: 13,
                  ),
                ),
              ],
              if (Platform.isAndroid) ...[
                const SizedBox(height: 14),
                Text(
                  'Перед установкою APK в?дкрийте налаштування й дайте дозв?л '
                  'на встановлення з нев?домих джерел.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openUrl(result.releaseUrl),
            child: const Text('Переглянути рел?з'),
          ),
          if (result.updateAvailable && result.downloadUrl != null)
            TextButton(
              onPressed: () => _downloadAndInstallApk(result.downloadUrl!),
              child: const Text('Оновити'),
            ),
          if (Platform.isAndroid)
            TextButton(
              onPressed: _openInstallSettings,
              child: const Text('Налаштування установки'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрити'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося в?дкрити ${uri.toString()}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося в?дкрити посилання: $error')),
      );
    }
  }

  Future<void> _openInstallSettings() async {
    if (!Platform.isAndroid) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
        data: 'package:${packageInfo.packageName}',
      );
      await intent.launch();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося в?дкрити налаштування: $error')),
      );
    }
  }

  Future<void> _downloadAndInstallApk(Uri apkUri) async {
    if (!Platform.isAndroid) {
      await _openUrl(apkUri);
      return;
    }

    if (!apkUri.path.toLowerCase().endsWith('.apk')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APK файл не знайдено в релізі. Додайте app-release.apk.'),
          ),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/freeobmin_update_$stamp.apk');
    double progress = 0;
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          dialogSetState = setState;
          return AlertDialog(
            title: const Text('Завантаження оновлення'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Dio().download(
        apkUri.toString(),
        file.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final value = received / total;
          if (dialogSetState != null) {
            dialogSetState!(() => progress = value);
          }
        },
      );

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося запустити встановлення: ${result.message}')),
        );
      }
    } catch (error) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження APK: $error')),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final showOnline = neoStore.sShowOnlineStatus;
    if (!showOnline) return;

    if (state == AppLifecycleState.resumed) {
      neoStore.setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      neoStore.setOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface.withAlpha(77),
              Theme.of(context).colorScheme.surfaceContainer.withAlpha(26),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            FadeTransition(
              opacity: _animation,
              child: ScaleTransition(
                scale: _animation,
                child: Builder(
                  builder: (context) {
                    if (!neoStore.ready) {
                      return const _NeoSplash();
                    }
                    return const NeoShell();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeoSplash extends StatelessWidget {
  const _NeoSplash();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.surface,
                cs.surfaceContainer.withAlpha(204),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: NeoThemes.getNeonDecoration(NeoThemes.currentColor),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [
                    NeoThemes.currentColor,
                    NeoThemes.currentNeon,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Text(
                'FreeObmin',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Створено, щоб підтримати людей у складний період для країни. Усе безкоштовно — обмінюйтесь речами, знаходьте потрібне та допомагайте одне одному.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withAlpha(160),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Завантаження...',
              style: TextStyle(
                color: cs.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeoShell extends StatefulWidget {
  const NeoShell({super.key});

  @override
  State<NeoShell> createState() => _NeoShellState();
}

class _NeoShellState extends State<NeoShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Слушаем изменения состояния пользователя
    neoStore.addListener(_handleUserChange);
  }

  @override
  void dispose() {
    neoStore.removeListener(_handleUserChange);
    super.dispose();
  }

  void _handleUserChange() {
    // Если пользователь вышел, переключаем на профиль (где форма входа)
    if (neoStore.user == null && _selectedIndex != 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 3; // Переключаем на вкладку профілю
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: NeoThemes.getAppBackground(context),
            ),
          ),
          _getPage(),
          _buildBlockedBanner(context),
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 6),
              child: _NeoNavBar(
                index: _selectedIndex,
                onTap: _handleNavTap,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _NeoFAB(
        onTap: () => _handleCreate(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _getPage() {
    switch (_selectedIndex) {
      case 0:
        return const NeoFeed();
      case 1:
        return neoStore.user == null ? const NeoProfile() : const NeoChats();
      case 2:
        return neoStore.user == null
            ? const NeoProfile()
            : const NeoFavorites();
      case 3:
        return const NeoProfile();
      default:
        return const NeoFeed();
    }
  }

  Widget _buildBlockedBanner(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (context, _) {
        final user = neoStore.user;
        if (user == null || !user.isBlocked) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE53935)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Вас заблоковано',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (user.blockedReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    user.blockedReason!,
                    style: TextStyle(
                      color: Colors.red.withAlpha(180),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _openBlockAppealChat(context),
                  child: Text(
                    user.blockedByName?.isNotEmpty == true
                        ? 'Звʼязатися з модератором: ${user.blockedByName}'
                        : 'Звʼязатися з модератором',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBlockAppealChat(BuildContext context) async {
    final user = neoStore.user;
    if (user == null || user.blockedById == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Контакт модератора недоступний'),
        ),
      );
      return;
    }

    try {
      final chatId = await neoStore.ensureChatWith(
        peerId: user.blockedById!,
        peerName: user.blockedByName ?? 'Модератор',
        peerEmail: '',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(chatId: chatId),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
        ),
      );
    }
  }

  void _handleCreate() {
    if (neoStore.user == null) {
      _redirectToAuth('Щоб додати оголошення, увійдіть або зареєструйтесь.');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NeoCreateItemPage(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _handleNavTap(int index) {
    if (neoStore.user == null && (index == 1 || index == 2)) {
      _redirectToAuth('Увійдіть, щоб відкривати чати та обране.');
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _redirectToAuth(String message) {
    setState(() => _selectedIndex = 3);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _NeoNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _NeoNavBar({
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface.withAlpha(isDark ? 220 : 235),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.outline.withAlpha(90),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Стрічка',
                        active: index == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        icon: Icons.chat_rounded,
                        label: 'Чати',
                        active: index == 1,
                        badgeCount: neoStore.totalUnread,
                        onTap: () => onTap(1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        icon: Icons.favorite_rounded,
                        label: 'Обране',
                        active: index == 2,
                        onTap: () => onTap(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        icon: Icons.person_rounded,
                        label: 'Профіль',
                        active: index == 3,
                        onTap: () => onTap(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hover) {
    if (hover) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = NeoThemes.currentColor;
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.active ? color.withAlpha(28) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    widget.active ? color.withAlpha(120) : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      widget.icon,
                      color:
                          widget.active ? color : cs.onSurface.withAlpha(150),
                      size: 22,
                    ),
                    if (widget.badgeCount > 0)
                      Positioned(
                        top: -6,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${widget.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.active ? color : cs.onSurface.withAlpha(150),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoFAB extends StatefulWidget {
  final VoidCallback onTap;

  const _NeoFAB({required this.onTap});

  @override
  State<_NeoFAB> createState() => _NeoFABState();
}

class _NeoFABState extends State<_NeoFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hover) {
    if (hover) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = NeoThemes.currentColor;
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha(120),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===========================
        NEO FEED
=========================== */

class NeoFeed extends StatefulWidget {
  const NeoFeed({super.key});

  @override
  State<NeoFeed> createState() => _NeoFeedState();
}

class _NeoFeedState extends State<NeoFeed> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  List<String> _searchHistory = [];
  bool _showSearchHistory = false;
  String _historyKey = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // Добавляем слушатель к neoStore
    neoStore.addListener(_refresh);
    _historyKey = _buildHistoryKey();
    _loadSearchHistory();
    _searchFocus.addListener(() {
      setState(() {
        _showSearchHistory = _searchFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    // Не забываем удалить слушатель при dispose
    neoStore.removeListener(_refresh);
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      neoStore.loadMoreFeed();
    }
  }

  // Метод для обновления состояния
  void _refresh() {
    if (mounted) {
      final nextKey = _buildHistoryKey();
      if (nextKey != _historyKey) {
        _historyKey = nextKey;
        _loadSearchHistory();
      }
      setState(() {});
    }
  }

  String _buildHistoryKey() {
    final uid = neoStore.user?.uid;
    return uid?.isNotEmpty == true
        ? 'neo_search_history_$uid'
        : 'neo_search_history_guest';
  }

  Future<void> _loadSearchHistory() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_historyKey);
    if (raw == null) {
      _searchHistory = [];
    } else {
      try {
        _searchHistory =
            (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {
        _searchHistory = [];
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveSearchHistory() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_historyKey, jsonEncode(_searchHistory));
  }

  Future<void> _addSearchHistory(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    _searchHistory.removeWhere((q) => q.toLowerCase() == value.toLowerCase());
    _searchHistory.insert(0, value);
    if (_searchHistory.length > 12) {
      _searchHistory = _searchHistory.take(12).toList();
    }
    await _saveSearchHistory();
    if (mounted) setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    _searchHistory = [];
    await _saveSearchHistory();
    if (mounted) setState(() {});
  }

  Widget _buildSearchHistory(ColorScheme cs) {
    if (!_showSearchHistory || _searchHistory.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Історія пошуку',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearSearchHistory,
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: _searchHistory.map((query) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _searchController.text = query;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: query.length),
                    );
                    neoStore.setSearchQuery(query);
                    setState(() {
                      _showSearchHistory = false;
                    });
                    _searchFocus.unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cs.surfaceContainer,
                      border: Border.all(
                        color: NeoThemes.currentColor.withAlpha(51),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: cs.onSurface.withAlpha(128),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 16,
                          color: cs.onSurface.withAlpha(128),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getSearchSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    final suggestions = <String>{};
    final items = neoStore.getApprovedItems();

    if (query.isEmpty) {
      suggestions.addAll(_searchHistory.take(4));
      final counts = <String, int>{};
      for (final item in items) {
        final key = item.category.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted.take(6)) {
        suggestions.add(entry.key);
      }
      return suggestions.toList();
    }

    for (final q in _searchHistory) {
      if (q.toLowerCase().contains(query)) suggestions.add(q);
    }
    for (final item in items) {
      if (item.title.toLowerCase().contains(query)) {
        suggestions.add(item.title);
      }
      if (item.category.toLowerCase().contains(query)) {
        suggestions.add(item.category);
      }
      if (item.city.toLowerCase().contains(query)) {
        suggestions.add(item.city);
      }
      if (suggestions.length >= 8) break;
    }
    return suggestions.toList();
  }

  List<Item> _getSmartSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length < 2) return const [];
    final items = neoStore.getApprovedItems();
    final scored = <Item, int>{};
    for (final item in items) {
      final score = neoStore.searchScore(item, query);
      if (score > 0) scored[item] = score;
    }
    final list = scored.keys.toList()
      ..sort((a, b) {
        final sa = scored[a] ?? 0;
        final sb = scored[b] ?? 0;
        if (sa != sb) return sb.compareTo(sa);
        if (a.likes != b.likes) return b.likes.compareTo(a.likes);
        return b.createdAt.compareTo(a.createdAt);
      });
    return list.take(6).toList();
  }

  Widget _buildSearchSuggestions(ColorScheme cs) {
    if (!_showSearchHistory) return const SizedBox();
    final suggestions = _getSearchSuggestions();
    if (suggestions.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Підказки',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((value) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = value;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: value.length),
                  );
                  neoStore.setSearchQuery(value);
                  _addSearchHistory(value);
                  setState(() {
                    _showSearchHistory = false;
                  });
                  _searchFocus.unfocus();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: NeoThemes.currentColor.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(180),
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.surface.withAlpha(230),
                  cs.surface.withAlpha(153),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'FreeObmin',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        // Кнопка уведомлений вместо логина
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationsPage(),
                              ),
                            );
                          },
                          icon: Badge(
                            isLabelVisible:
                                neoStore.totalUnreadNotifications > 0,
                            label: Text(
                              '${neoStore.totalUnreadNotifications}',
                            ),
                            child: const Icon(Icons.notifications_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outline.withAlpha(120)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(
                                Theme.of(context).brightness == Brightness.dark
                                    ? 70
                                    : 18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: 'Що шукаєте сьогодні?',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: cs.onSurface.withAlpha(140),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        onChanged: (value) {
                          neoStore.setSearchQuery(value);
                          setState(() {});
                        },
                        onSubmitted: (value) {
                          _addSearchHistory(value);
                          neoStore.setSearchQuery(value);
                        },
                      ),
                    ),
                    _buildSearchHistory(cs),
                    _buildSearchSuggestions(cs),
                    const SizedBox(height: 16),
                    // Добавляем Key к виджету, чтобы он перестраивался
                    _FilterChipsBar(
                        key: ValueKey(neoStore.filteredItems.length)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final suggestions = _getSmartSuggestions();
              if (suggestions.isEmpty) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Схожі оголошення',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final item = suggestions[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NeoItemDetailPage(
                                    itemId: item.id,
                                    initialItem: item,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 180,
                              margin: EdgeInsets.only(
                                  right:
                                      index < suggestions.length - 1 ? 12 : 0),
                              decoration: NeoThemes.getCardDecoration(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                      child: item.getImageAtIndex(
                                        context,
                                        0,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.city,
                                          style: TextStyle(
                                            color: cs.onSurface.withAlpha(128),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final items = neoStore.visibleFilteredItems;
                final canLoadMore = neoStore.canLoadMoreFeed;
                if (index < items.length) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NeoItemDetailPage(
                            itemId: item.id,
                            initialItem: item,
                          ),
                        ),
                      );
                    },
                    child: _NeoItemCard(item: item),
                  );
                }
                if (canLoadMore && index == items.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NeoThemes.currentColor,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              childCount: neoStore.canLoadMoreFeed
                  ? neoStore.visibleFilteredItems.length + 1
                  : neoStore.visibleFilteredItems.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _FilterChipsBar extends StatefulWidget {
  const _FilterChipsBar({super.key});

  @override
  State<_FilterChipsBar> createState() => __FilterChipsBarState();
}

class __FilterChipsBarState extends State<_FilterChipsBar> {
  @override
  void initState() {
    super.initState();
    // Добавляем слушатель к neoStore
    neoStore.addListener(_refresh);
  }

  @override
  void dispose() {
    neoStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = [
      if (neoStore.selectedCategory != 'Усі') neoStore.selectedCategory,
      if (neoStore.selectedCity != 'Усі') neoStore.selectedCity,
      if (neoStore.selectedType != null) neoStore.selectedType!.label,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Усі',
                      active: neoStore.selectedCategory == 'Усі' &&
                          neoStore.selectedCity == 'Усі' &&
                          neoStore.selectedType == null,
                      onTap: () => neoStore.clearFilters(),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Фільтри',
                      active: activeFilters.isNotEmpty,
                      icon: Icons.filter_alt_rounded,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const _FilterSheet(),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: neoStore.sortBy == 'newest'
                          ? 'Спочатку нові'
                          : 'Спочатку старі',
                      active: true,
                      icon: neoStore.sortBy == 'newest'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      onTap: () {
                        neoStore.setFilters(
                          sort:
                              neoStore.sortBy == 'newest' ? 'oldest' : 'newest',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => const _FilterSheet(),
                );
              },
              icon: Icon(
                Icons.tune_rounded,
                color: NeoThemes.currentColor,
              ),
            ),
          ],
        ),
        if (activeFilters.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: activeFilters.map((filter) {
              return GestureDetector(
                onTap: () {
                  _openEditFilterDialog(context, filter);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: NeoThemes.currentColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: NeoThemes.currentColor.withAlpha(77),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter,
                        style: TextStyle(
                          color: NeoThemes.currentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          if (filter == neoStore.selectedCategory &&
                              filter != 'Усі') {
                            neoStore.setFilters(category: 'Усі');
                          } else if (filter == neoStore.selectedCity &&
                              filter != 'Усі') {
                            neoStore.setFilters(city: 'Усі');
                          } else if (neoStore.selectedType?.label == filter) {
                            neoStore.setFilters(type: null);
                          }
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: NeoThemes.currentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _openEditFilterDialog(BuildContext context, String filter) {
    showDialog(
      context: context,
      builder: (context) {
        return FilterEditDialog(
          currentFilter: filter,
          filterType: _getFilterType(filter),
        );
      },
    );
  }

  String _getFilterType(String filter) {
    if (neoStore.selectedCategory == filter) return 'category';
    if (neoStore.selectedCity == filter) return 'city';
    if (neoStore.selectedType?.label == filter) return 'type';
    return 'unknown';
  }
}

class FilterEditDialog extends StatefulWidget {
  final String currentFilter;
  final String filterType;

  const FilterEditDialog({
    super.key,
    required this.currentFilter,
    required this.filterType,
  });

  @override
  State<FilterEditDialog> createState() => _FilterEditDialogState();
}

class _FilterEditDialogState extends State<FilterEditDialog> {
  late String _selectedCategory;
  late String _selectedCity;
  late ItemType? _selectedType;
  late String _selectedSort;
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = neoStore.selectedCategory;
    _selectedCity = neoStore.selectedCity;
    _selectedType = neoStore.selectedType;
    _selectedSort = neoStore.sortBy;
    _cityController.text = _selectedCity;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showLocationPicker(
      context,
      initialCity: _selectedCity,
      allowAll: true,
    );
    if (city != null) {
      setState(() {
        _selectedCity = city;
        _cityController.text = city;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Редагувати фільтр',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Поточний фільтр: ${widget.currentFilter}',
                style: TextStyle(
                  color: cs.onSurface.withAlpha(179),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.filterType == 'category') ...[
                Text(
                  'Оберіть категорію',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: neoStore.availableCategories.map((category) {
                    return _FilterOptionChip(
                      label: category,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    );
                  }).toList(),
                ),
              ] else if (widget.filterType == 'city') ...[
                Text(
                  'Оберіть місто',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                NeoInput(
                  controller: _cityController,
                  hint: 'Оберіть місто',
                  prefixIcon: Icons.location_on_rounded,
                  suffixIcon: Icons.keyboard_arrow_down_rounded,
                  readOnly: true,
                  onTap: _pickCity,
                ),
              ] else if (widget.filterType == 'type') ...[
                Text(
                  'Оберіть тип',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterOptionChip(
                      label: 'Усі',
                      selected: _selectedType == null,
                      onTap: () => setState(() => _selectedType = null),
                    ),
                    _FilterOptionChip(
                      label: 'Обмін',
                      selected: _selectedType == ItemType.exchange,
                      onTap: () =>
                          setState(() => _selectedType = ItemType.exchange),
                    ),
                    _FilterOptionChip(
                      label: 'Подарунок',
                      selected: _selectedType == ItemType.gift,
                      onTap: () =>
                          setState(() => _selectedType = ItemType.gift),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Сортування',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterOptionChip(
                    label: 'Спочатку нові',
                    icon: Icons.arrow_downward_rounded,
                    selected: _selectedSort == 'newest',
                    onTap: () => setState(() => _selectedSort = 'newest'),
                  ),
                  _FilterOptionChip(
                    label: 'Спочатку старі',
                    icon: Icons.arrow_upward_rounded,
                    selected: _selectedSort == 'oldest',
                    onTap: () => setState(() => _selectedSort = 'oldest'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      text: 'Скасувати',
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoButton(
                      text: 'Застосувати',
                      onPressed: () {
                        neoStore.setFilters(
                          category: widget.filterType == 'category'
                              ? _selectedCategory
                              : null,
                          city: widget.filterType == 'city'
                              ? _selectedCity
                              : null,
                          type: widget.filterType == 'type'
                              ? _selectedType
                              : null,
                          sort: _selectedSort,
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              NeoTextButton(
                text: 'Скинути всі фільтри',
                onPressed: () {
                  neoStore.clearFilters();
                  Navigator.pop(context);
                },
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => __FilterSheetState();
}

class __FilterSheetState extends State<_FilterSheet> {
  late String _tempCategory;
  late String _tempCity;
  late ItemType? _tempType;
  late String _tempSort;
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempCategory = neoStore.selectedCategory;
    _tempCity = neoStore.selectedCity;
    _tempType = neoStore.selectedType;
    _tempSort = neoStore.sortBy;
    _cityController.text = _tempCity;
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickFilterCity() async {
    final city = await showLocationPicker(
      context,
      initialCity: _tempCity,
      allowAll: true,
    );
    if (city != null) {
      setState(() {
        _tempCity = city;
        _cityController.text = city;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Фільтри та сортування',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Категорія',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: neoStore.availableCategories.map((category) {
                return _FilterOptionChip(
                  label: category,
                  selected: _tempCategory == category,
                  onTap: () => setState(() => _tempCategory = category),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Місто',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            NeoInput(
              controller: _cityController,
              hint: 'Оберіть місто',
              prefixIcon: Icons.location_on_rounded,
              suffixIcon: Icons.keyboard_arrow_down_rounded,
              readOnly: true,
              onTap: _pickFilterCity,
            ),
            const SizedBox(height: 24),
            Text(
              'Тип оголошення',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterOptionChip(
                  label: 'Усі',
                  selected: _tempType == null,
                  onTap: () => setState(() => _tempType = null),
                ),
                _FilterOptionChip(
                  label: 'Обмін',
                  selected: _tempType == ItemType.exchange,
                  onTap: () => setState(() => _tempType = ItemType.exchange),
                ),
                _FilterOptionChip(
                  label: 'Подарунок',
                  selected: _tempType == ItemType.gift,
                  onTap: () => setState(() => _tempType = ItemType.gift),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Сортування',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterOptionChip(
                  label: 'Спочатку нові',
                  icon: Icons.arrow_downward_rounded,
                  selected: _tempSort == 'newest',
                  onTap: () => setState(() => _tempSort = 'newest'),
                ),
                _FilterOptionChip(
                  label: 'Спочатку старі',
                  icon: Icons.arrow_upward_rounded,
                  selected: _tempSort == 'oldest',
                  onTap: () => setState(() => _tempSort = 'oldest'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    text: 'Скинути',
                    onPressed: () {
                      setState(() {
                        _tempCategory = 'Усі';
                        _tempCity = 'Усі';
                        _tempType = null;
                        _tempSort = 'newest';
                      });
                    },
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoButton(
                    text: 'Застосувати',
                    onPressed: () {
                      neoStore.setFilters(
                        category: _tempCategory,
                        city: _tempCity,
                        type: _tempType,
                        sort: _tempSort,
                      );
                      Navigator.pop(context); // Закрываем диалог
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = NeoThemes.currentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(38) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withAlpha(77) : Colors.grey.withAlpha(77),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => __FilterChipState();
}

class __FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hover) {
    if (hover) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = NeoThemes.currentColor;
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.active
                  ? color.withAlpha(38)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.active
                    ? color.withAlpha(77)
                    : cs.outline.withAlpha(51),
                width: 1.5,
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: color.withAlpha(51),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16,
                    color: widget.active ? color : cs.onSurface.withAlpha(204),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.active ? color : cs.onSurface.withAlpha(204),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoItemCard extends StatefulWidget {
  final Item item;

  const _NeoItemCard({required this.item});

  @override
  State<_NeoItemCard> createState() => __NeoItemCardState();
}

class __NeoItemCardState extends State<_NeoItemCard> {
  bool _isFavorite = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = neoStore.isFav(widget.item.id);
  }

  void _toggleFavorite() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Визуальная обратная связь - сразу меняем состояние
    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      await neoStore.toggleFav(widget.item.id);
    } catch (e) {
      // В случае ошибки возвращаем предыдущее состояние
      setState(() {
        _isFavorite = !_isFavorite;
      });
      print('Помилка додавання до обраного: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = NeoThemes.currentColor;
    final typeColor = widget.item.type.accent;

    return Container(
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: widget.item.getImageWidget(
                      context,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: typeColor.withAlpha(190),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.item.type.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(170),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withAlpha(50),
                        ),
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: _isFavorite
                                    ? Colors.redAccent
                                    : Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withAlpha(160),
                        height: 1.4,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: accent.withAlpha(160),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.item.city,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: cs.onSurface.withAlpha(170),
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        ITEM DETAIL PAGE
=========================== */

class NeoItemDetailPage extends StatefulWidget {
  final String itemId;
  final Item? initialItem;

  const NeoItemDetailPage({
    super.key,
    required this.itemId,
    this.initialItem,
  });

  @override
  State<NeoItemDetailPage> createState() => _NeoItemDetailPageState();
}

class _NeoItemDetailPageState extends State<NeoItemDetailPage> {
  Item? _item;
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _viewerRegistered = false;
  bool _loadingItem = true;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    if (_item != null) {
      _isFavorite = neoStore.isFav(_item!.id);
      _currentImageIndex = _item!.mainImageIndex;
    }
    _loadItem();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      neoStore.incrementViews(widget.itemId);
      if (!_viewerRegistered) {
        neoStore.setActiveViewer(widget.itemId, true);
        _viewerRegistered = true;
      }
    });
  }

  Future<void> _loadItem() async {
    final fetched = await neoStore.fetchItemById(widget.itemId);
    if (!mounted) return;
    if (fetched != null) {
      setState(() {
        _item = fetched;
        _isFavorite = neoStore.isFav(fetched.id);
        _currentImageIndex = fetched.mainImageIndex;
        _loadingItem = false;
      });
    } else {
      setState(() {
        _loadingItem = false;
      });
    }
  }

  @override
  void dispose() {
    if (_viewerRegistered) {
      neoStore.setActiveViewer(widget.itemId, false);
    }
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    neoStore.toggleFav(widget.itemId);
  }

  Future<void> _showItemReportDialog(Item item) async {
    final reporter = neoStore.user;
    if (reporter == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Увійдіть, щоб надіслати скаргу')),
      );
      return;
    }
    if (reporter.uid == item.ownerId) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Не можна скаржитися на власне оголошення')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поскаржитися на оголошення'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишіть причину скарги',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Надіслати'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await neoStore.submitComplaint(
      reportedUserId: item.ownerId,
      reportedUserName: item.ownerName,
      reason: result,
      itemId: item.id,
      itemTitle: item.title,
    );

    if (!mounted) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скаргу надіслано модератору')),
    );
  }

  void _openImageFullScreen(int index) {
    final item = _item;
    if (item == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NeoImageFullScreen(
          images: item.allPhotos,
          initialIndex: index,
        ),
      ),
    );
  }

  void _viewSellerProfile() {
    final item = _item;
    if (item == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerProfilePage(
          sellerId: item.ownerId,
        ),
      ),
    );
  }

  Future<void> _shareItem(Item item) async {
    final url = await neoStore.buildShareUrl(item);
    await Share.share(url, subject: item.title);
  }

  Widget _buildProfileImage(String userId, String name) {
    return FutureBuilder<String?>(
      future: neoStore.fetchUserProfileImageUrl(userId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url?.isNotEmpty == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: CachedNetworkImage(
              imageUrl: url!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, value) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeoThemes.currentColor,
                ),
              ),
              errorWidget: (context, value, error) {
                return _buildDefaultProfileAvatar(name);
              },
            ),
          );
        }
        return _buildDefaultProfileAvatar(name);
      },
    );
  }

  Widget _buildDefaultProfileAvatar(String name) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeoThemes.currentColor,
            NeoThemes.currentNeon,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.substring(0, 1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Оголошення'),
        ),
        body: Center(
          child: _loadingItem
              ? const CircularProgressIndicator()
              : const Text('Оголошення не знайдено'),
        ),
      );
    }
    final images = item.allPhotos;
    final similarItems = neoStore.getSimilarItems(item);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _openImageFullScreen(index),
                          child: item.getImageAtIndex(context, index,
                              fit: BoxFit.cover, iconSize: 60),
                        );
                      },
                    )
                  else
                    Container(
                      color: cs.surfaceContainer,
                      child: Center(
                        child: Icon(
                          item.type.icon,
                          color: cs.onSurface.withAlpha(77),
                          size: 60,
                        ),
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withAlpha(128),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        item.title,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shareItem(item),
                      icon: const Icon(Icons.share_rounded),
                    ),
                    IconButton(
                      onPressed: () => _showItemReportDialog(item),
                      icon: const Icon(
                        Icons.report_gmailerrorred_rounded,
                        color: Colors.red,
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: _isFavorite ? Colors.red : cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.type.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.type.accent.withAlpha(77),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.type.icon,
                            size: 16,
                            color: item.type.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.type.label,
                            style: TextStyle(
                              color: item.type.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.status.color.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.status.color.withAlpha(77),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.status.icon,
                            size: 16,
                            color: item.status.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.status.label,
                            style: TextStyle(
                              color: item.status.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: cs.onSurface.withAlpha(128),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.city,
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(128),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NeoThemes.getCardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Описание',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        item.desc,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(204),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (neoStore.user?.uid == item.ownerId)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseService.firestore!
                        .collection('items')
                        .doc(item.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final data =
                          snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      final viewers =
                          List<String>.from(data['activeViewers'] ?? []);
                      final meId = neoStore.user?.uid;
                      var activeCount = viewers.length;
                      if (meId != null && viewers.contains(meId)) {
                        activeCount -= 1;
                      }
                      if (activeCount <= 0) return const SizedBox();
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NeoThemes.currentColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: NeoThemes.currentColor.withAlpha(77),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: NeoThemes.currentColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Сейчас просматривают: $activeCount',
                              style: TextStyle(
                                color: NeoThemes.currentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NeoThemes.getCardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Інформація про продавця',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _viewSellerProfile,
                        child: Row(
                          children: [
                            _buildProfileImage(item.ownerId, item.ownerName),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ownerName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Місто: ${item.city}',
                                    style: TextStyle(
                                      color: cs.onSurface.withAlpha(153),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurface.withAlpha(77),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      NeoButton(
                        text: 'Переглянути профіль продавця',
                        onPressed: _viewSellerProfile,
                        fullWidth: true,
                        icon: Icons.person_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: NeoThemes.getCardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Информация',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Категорія',
                                style: TextStyle(
                                  color: cs.onSurface.withAlpha(128),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.category,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Перегляди',
                                style: TextStyle(
                                  color: cs.onSurface.withAlpha(128),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.remove_red_eye_rounded,
                                    size: 16,
                                    color: cs.onSurface.withAlpha(179),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.views}',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (item.ownerId == neoStore.user?.uid)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Вподобання',
                                  style: TextStyle(
                                    color: cs.onSurface.withAlpha(128),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite_rounded,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item.likes}',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Дата публикации',
                                style: TextStyle(
                                  color: cs.onSurface.withAlpha(128),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Время',
                                style: TextStyle(
                                  color: cs.onSurface.withAlpha(128),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                          const SizedBox(width: 60),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID оголошення',
                                style: TextStyle(
                                  color: cs.onSurface.withAlpha(128),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.id,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // В NeoItemDetailPage в методе build, ищем блок похожих оголошень:
                if (similarItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Схожі оголошення',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200, // Увеличим высоту для лучшего отображения
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: similarItems.length,
                      itemBuilder: (context, index) {
                        final similarItem = similarItems[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NeoItemDetailPage(
                                  itemId: similarItem.id,
                                  initialItem: similarItem,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 180, // Фиксированная ширина
                            margin: EdgeInsets.only(
                                right:
                                    index < similarItems.length - 1 ? 12 : 0),
                            decoration: NeoThemes.getCardDecoration(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Измененный блок изображения
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      color: cs.surfaceContainer,
                                      child: similarItem.getImageAtIndex(
                                          context, 0,
                                          fit: BoxFit.cover, iconSize: 40),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        similarItem.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 12,
                                            color: cs.onSurface.withAlpha(128),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            similarItem.city,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  cs.onSurface.withAlpha(153),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (neoStore.user != null && neoStore.user!.uid != item.ownerId)
                  NeoButton(
                    text: 'Написати продавцю',
                    onPressed: () async {
                      if (!neoStore.canMessageUser(item.ownerId)) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Вас заблоковано. Для звʼязку використовуйте чат з модератором.',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        final chatId = await neoStore.ensureChatWith(
                          peerId: item.ownerId,
                          peerName: item.ownerName,
                          peerEmail: item.ownerEmail,
                          itemId: item.id,
                          itemTitle: item.title,
                        );
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatDetailPage(chatId: chatId),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Помилка: $e'),
                          ),
                        );
                      }
                    },
                    fullWidth: true,
                    icon: Icons.chat_rounded,
                  ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        SELLER PROFILE PAGE
=========================== */

class SellerProfilePage extends StatefulWidget {
  final String sellerId;

  const SellerProfilePage({
    super.key,
    required this.sellerId,
  });

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  late SessionUser? _seller;
  late List<Item> _sellerItems;
  late List<Item> _approvedItems;

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    final allItems = neoStore.itemsByOwner(widget.sellerId);
    _sellerItems = allItems;
    _approvedItems =
        allItems.where((item) => item.status == ItemStatus.approved).toList();

    if (_sellerItems.isNotEmpty) {
      final firstItem = _sellerItems.first;
      _seller = SessionUser(
        uid: widget.sellerId,
        name: firstItem.ownerName,
        email: firstItem.ownerEmail,
        city: firstItem.city,
        role: UserRole.user,
        likes: _sellerItems.fold(0, (sum, item) => sum + item.likes),
        level: (_sellerItems.length ~/ 3) + 1,
        itemsPosted: _sellerItems.length,
        itemsApproved: _approvedItems.length,
        exchangesCompleted: _sellerItems.length ~/ 2,
        profileImageUrl: null,
      );
    } else {
      _seller = null;
    }

    final profileImageUrl =
        await neoStore.fetchUserProfileImageUrl(widget.sellerId);
    if (_seller != null && profileImageUrl?.isNotEmpty == true) {
      _seller = _seller!.copyWith(profileImageUrl: profileImageUrl);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildProfileImage() {
    if (_seller?.profileImageUrl?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: CachedNetworkImage(
          imageUrl: _seller!.profileImageUrl!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NeoThemes.currentColor,
            ),
          ),
          errorWidget: (context, url, error) {
            return _buildDefaultAvatar();
          },
        ),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeoThemes.currentColor,
            NeoThemes.currentNeon,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: NeoThemes.currentColor.withAlpha(77),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _seller?.name.substring(0, 1) ?? 'U',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 40,
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDialog() async {
    final reporter = neoStore.user;
    if (reporter == null || _seller == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Увійдіть, щоб надіслати скаргу')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поскаржитися'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишіть причину скарги',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Надіслати'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await neoStore.submitComplaint(
      reportedUserId: _seller!.uid,
      reportedUserName: _seller!.name,
      reason: result,
    );

    if (!mounted) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скаргу надіслано модератору')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_seller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Профіль продавця'),
        ),
        body: const Center(
          child: Text('Користувача не знайдено'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Профіль ${_seller!.name}'),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NeoThemes.currentColor.withAlpha(77),
                    cs.surface.withAlpha(153),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  _buildProfileImage(),
                  const SizedBox(height: 16),
                  Text(
                    _seller!.name,
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Контакти приховані',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(153),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeoThemes.currentColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NeoThemes.currentColor.withAlpha(77),
                      ),
                    ),
                    child: Text(
                      'Продавець',
                      style: TextStyle(
                        color: NeoThemes.currentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: NeoThemes.getCardDecoration(context),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              value: '${_seller!.itemsPosted}',
                              label: 'Усього',
                              icon: Icons.list_alt_rounded,
                            ),
                            _StatItem(
                              value: '${_seller!.itemsApproved}',
                              label: 'Активні',
                              icon: Icons.check_circle_rounded,
                            ),
                            _StatItem(
                              value: '${_seller!.likes}',
                              label: 'Вподобання',
                              icon: Icons.favorite_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              value: '${_seller!.exchangesCompleted}',
                              label: 'Обміни',
                              icon: Icons.swap_horiz_rounded,
                            ),
                            _StatItem(
                              value: '${_seller!.level}',
                              label: 'Рівень',
                              icon: Icons.star_rounded,
                            ),
                            _StatItem(
                              value: _seller!.city,
                              label: 'Місто',
                              icon: Icons.location_on_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (neoStore.user != null &&
                      neoStore.user!.uid != widget.sellerId) ...[
                    const SizedBox(height: 16),
                    NeoButton(
                      text: 'Поскаржитися',
                      onPressed: _showReportDialog,
                      fullWidth: true,
                      color: Colors.red,
                      icon: Icons.report_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Оголошення продавця (${_approvedItems.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (_approvedItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: NeoThemes.getCardDecoration(context),
                  child: Column(
                    children: [
                      Icon(
                        Icons.list_alt_rounded,
                        size: 60,
                        color: cs.onSurface.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Немає оголошень',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'У цього продавця поки немає активних оголошень',
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _approvedItems[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NeoItemDetailPage(
                              itemId: item.id,
                              initialItem: item,
                            ),
                          ),
                        );
                      },
                      child: _NeoItemCard(item: item),
                    );
                  },
                  childCount: _approvedItems.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AnimatedBuilder(
        animation: neoStore,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Адмін панель'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Огляд'),
                  Tab(text: 'Користувачі'),
                  Tab(text: 'Скарги'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _AdminOverviewTab(),
                _AdminUsersTab(),
                _AdminComplaintsTab(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminOverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final totalItems = neoStore.items.length;
    final approvedItems = neoStore.getApprovedItems().length;
    final pendingItems = neoStore.getPendingItems().length;
    final openComplaints =
        neoStore.complaints.where((c) => c.status == 'open').length;
    final chats = neoStore.chats.length;
    final notifications = neoStore.notifications.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Огляд',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AdminStatCard(
              title: 'Усього оголошень',
              value: totalItems.toString(),
              icon: Icons.inventory_2_rounded,
            ),
            _AdminStatCard(
              title: 'Схвалено',
              value: approvedItems.toString(),
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
            ),
            _AdminStatCard(
              title: 'На модерації',
              value: pendingItems.toString(),
              icon: Icons.pending_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _AdminStatCard(
              title: 'Скарги',
              value: openComplaints.toString(),
              icon: Icons.report_rounded,
              color: const Color(0xFFEF4444),
            ),
            _AdminStatCard(
              title: 'Чати',
              value: chats.toString(),
              icon: Icons.chat_bubble_rounded,
            ),
            _AdminStatCard(
              title: 'Сповіщення',
              value: notifications.toString(),
              icon: Icons.notifications_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Швидкі дії',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        NeoButton(
          text: 'Модерація оголошень',
          icon: Icons.gavel_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NeoModerationPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        NeoButton(
          text: 'Список скарг',
          icon: Icons.report_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NeoModerationPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        NeoButton(
          text: 'Сповіщення',
          icon: Icons.notifications_rounded,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdminUsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final users = neoStore.users;
    if (users.isEmpty) {
      return Center(
        child: Text(
          'Користувачів поки немає',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = neoStore.user?.uid == user.uid;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminUserDetailPage(user: user),
                ),
              );
            },
            child: _AdminUserTile(user: user, isSelf: isSelf),
          ),
        );
      },
    );
  }
}

class _AdminComplaintsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final list = neoStore.complaints;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Скарг поки немає',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _ComplaintCard(complaint: list[index]);
      },
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlocked = neoStore.user?.isBlocked == true;
    final accent = color ?? NeoThemes.currentColor;
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(14),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: NeoThemes.getNeonDecoration(accent),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface.withAlpha(140),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserTile extends StatelessWidget {
  final SessionUser user;
  final bool isSelf;

  const _AdminUserTile({required this.user, required this.isSelf});

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Адміністратор';
      case UserRole.moderator:
        return 'Модератор';
      case UserRole.user:
      default:
        return 'Користувач';
    }
  }

  Widget _buildAvatar() {
    if (user.profileImageUrl?.isNotEmpty == true) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.profileImageUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, value) => const SizedBox(
            width: 44,
            height: 44,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, value, error) => _buildFallbackAvatar(),
        ),
      );
    }
    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: 22,
      backgroundColor: NeoThemes.currentColor.withAlpha(180),
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _toggleBlock(BuildContext context) async {
    if (isSelf) return;
    if (user.isBlocked) {
      await neoStore.setUserBlocked(userId: user.uid, blocked: false);
      return;
    }

    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Причина блокування'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишіть причину блокування',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Заблокувати'),
          ),
        ],
      ),
    );

    if (reason != null) {
      await neoStore.setUserBlocked(
        userId: user.uid,
        blocked: true,
        reason: reason.isEmpty ? null : reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleText = _roleLabel(user.role);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(140),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.city,
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (user.isBlocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withAlpha(90)),
                  ),
                  child: const Text(
                    'Заблоковано',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withAlpha(120)),
                ),
                child: Text(
                  roleText,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(170),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<UserRole>(
                enabled: !isSelf,
                onSelected: (role) {
                  neoStore.setUserRole(userId: user.uid, role: role);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: UserRole.user,
                    child: Text('Користувач'),
                  ),
                  const PopupMenuItem(
                    value: UserRole.moderator,
                    child: Text('Модератор'),
                  ),
                  const PopupMenuItem(
                    value: UserRole.admin,
                    child: Text('Адміністратор'),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withAlpha(120)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.manage_accounts_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Роль'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isSelf ? null : () => _toggleBlock(context),
                icon: Icon(
                  user.isBlocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  size: 18,
                  color: user.isBlocked ? Colors.green : Colors.red,
                ),
                label: Text(
                  user.isBlocked ? 'Розблокувати' : 'Блокувати',
                  style: TextStyle(
                    color: user.isBlocked ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminUserDetailPage extends StatelessWidget {
  final SessionUser user;

  const AdminUserDetailPage({super.key, required this.user});

  String _formatDate(DateTime? value) {
    if (value == null) return 'Невідомо';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = neoStore.itemsByOwner(user.uid);
    final phone =
        user.phone?.trim().isNotEmpty == true ? user.phone! : 'Не вказано';

    return Scaffold(
      appBar: AppBar(
        title: Text('Користувач: ${user.name}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: NeoThemes.getCardDecoration(context),
            child: Row(
              children: [
                if (user.profileImageUrl?.isNotEmpty == true)
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.profileImageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (context, value) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, value, error) =>
                          const Icon(Icons.person_rounded, size: 48),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: NeoThemes.currentColor.withAlpha(180),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.city,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(130),
                          fontSize: 12,
                        ),
                      ),
                      if (user.isBlocked) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Заблоковано',
                          style: TextStyle(
                            color: Colors.red.withAlpha(220),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AdminStatCard(
                title: 'Оголошень',
                value: user.itemsPosted.toString(),
                icon: Icons.inventory_2_rounded,
              ),
              _AdminStatCard(
                title: 'Схвалено',
                value: user.itemsApproved.toString(),
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
              ),
              _AdminStatCard(
                title: 'Лайків',
                value: user.likes.toString(),
                icon: Icons.favorite_rounded,
                color: const Color(0xFFEF4444),
              ),
              _AdminStatCard(
                title: 'Обміни',
                value: user.exchangesCompleted.toString(),
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: NeoThemes.getCardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дані профілю',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Дата реєстрації: ${_formatDate(user.createdAt)}',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(170),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Телефон: $phone',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(170),
                    fontSize: 13,
                  ),
                ),
                if (user.blockedReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Причина блокування: ${user.blockedReason}',
                    style: TextStyle(
                      color: Colors.red.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Оголошення користувача (${items.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Оголошень немає',
              style: TextStyle(
                color: cs.onSurface.withAlpha(140),
                fontSize: 12,
              ),
            )
          else
            ...items.take(6).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NeoItemDetailPage(
                          itemId: item.id,
                          initialItem: item,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline.withAlpha(51)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child:
                                item.getImageWidget(context, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.status.label,
                                style: TextStyle(
                                  color: item.status.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
/* ===========================
        IMAGE FULL SCREEN
=========================== */

class NeoImageFullScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const NeoImageFullScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<NeoImageFullScreen> createState() => _NeoImageFullScreenState();
}

class _NeoImageFullScreenState extends State<NeoImageFullScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final TransformationController _transformController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  static const double _maxZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildFullScreenImage(String imagePath) {
    final uri = Uri.tryParse(imagePath);
    final isHttp =
        imagePath.startsWith('http') || imagePath.startsWith('https');
    final isFile = uri?.scheme == 'file';

    if (isHttp) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) {
          return Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: Colors.white.withAlpha(128),
              size: 60,
            ),
          );
        },
      );
    } else {
      final filePath = isFile ? uri!.toFilePath() : imagePath;
      return Image.file(
        File(filePath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: Colors.white.withAlpha(128),
              size: 60,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _transformController.value = Matrix4.identity();
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: () {
                  final position = _doubleTapDetails?.localPosition;
                  if (position == null) return;
                  final currentScale =
                      _transformController.value.getMaxScaleOnAxis();
                  if (currentScale > 1.0) {
                    _transformController.value = Matrix4.identity();
                  } else {
                    final zoomed = Matrix4.identity()
                      ..translate(-position.dx * (_maxZoom - 1),
                          -position.dy * (_maxZoom - 1))
                      ..scale(_maxZoom);
                    _transformController.value = zoomed;
                  }
                },
                child: InteractiveViewer(
                  transformationController: _transformController,
                  maxScale: _maxZoom,
                  minScale: 0.8,
                  child: Center(
                    child: _buildFullScreenImage(widget.images[index]),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ===========================
        CHAT DETAIL PAGE
=========================== */

class ChatDetailPage extends StatefulWidget {
  final String chatId;

  const ChatDetailPage({super.key, required this.chatId});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  late ChatThread _chat;
  late VoidCallback _chatListener;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    final chat = neoStore.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => ChatThread(
        id: widget.chatId,
        peerId: 'unknown',
        peerName: 'Unknown',
        peerEmail: '',
        messages: [],
        blockedUsers: <String>{},
      ),
    );
    _chat = chat;
    _chatListener = () {
      final updated = neoStore.chats.firstWhere(
        (c) => c.id == widget.chatId,
        orElse: () => _chat,
      );
      if (updated != _chat) {
        setState(() => _chat = updated);
      }
    };
    neoStore.addListener(_chatListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      neoStore.markChatRead(widget.chatId);
      _showSafetyReminderIfNeeded();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    neoStore.removeListener(_chatListener);
    super.dispose();
  }

  Future<void> _showSafetyReminderIfNeeded() async {
    final sp = await SharedPreferences.getInstance();
    final uid = neoStore.user?.uid ?? 'guest';
    final key = 'neo_chat_safety_shown_$uid';
    if (sp.getBool(key) == true) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Безпека в чатах'),
        content: const Text(
          'Не переходьте за підозрілими посиланнями, не повідомляйте особисті дані та не переказуйте гроші завчасно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОК'),
          ),
        ],
      ),
    );

    await sp.setBool(key, true);
  }

  Widget _buildProfileImage(String peerId, String peerName) {
    return FutureBuilder<String?>(
      future: neoStore.fetchUserProfileImageUrl(peerId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url?.isNotEmpty == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CachedNetworkImage(
              imageUrl: url!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              placeholder: (context, value) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeoThemes.currentColor,
                ),
              ),
              errorWidget: (context, value, error) {
                return _buildDefaultPeerAvatar(peerName);
              },
            ),
          );
        }
        return _buildDefaultPeerAvatar(peerName);
      },
    );
  }

  Widget _buildDefaultPeerAvatar(String peerName) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeoThemes.currentColor,
            NeoThemes.currentNeon,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          peerName.substring(0, 1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatus(ColorScheme cs) {
    if (!neoStore.sShowOnlineStatus) return const SizedBox();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseService.firestore!
          .collection('users')
          .doc(_chat.peerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isOnline = data['online'] == true;
        final lastSeenRaw = data['lastSeen'] as String?;
        DateTime? lastSeen;
        if (lastSeenRaw != null && lastSeenRaw.isNotEmpty) {
          lastSeen = DateTime.tryParse(lastSeenRaw)?.toLocal();
        }

        String label;
        if (isOnline) {
          label = 'В мережі';
        } else if (lastSeen != null) {
          final hh = lastSeen.hour.toString().padLeft(2, '0');
          final mm = lastSeen.minute.toString().padLeft(2, '0');
          label = 'Був(ла) $hh:$mm';
        } else {
          label = 'Не в мережі';
        }

        return Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : cs.onSurface.withAlpha(128),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isOnline ? Colors.green : cs.onSurface.withAlpha(128),
              ),
            ),
          ],
        );
      },
    );
  }

  String _filePathFromImage(String? value) {
    if (value == null || value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'file') {
      return uri!.toFilePath();
    }
    return value;
  }

  void _sendMessage() {
    if (!neoStore.canMessageUser(_chat.peerId)) {
      _showToast(
        'Вас заблоковано. Для звʼязку використовуйте чат з модератором.',
      );
      return;
      if (_isChatBlockedForMe()) {
        _showToast('Ви заблоковані у цьому чаті.');
        return;
      }
    }
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      neoStore.sendMessage(widget.chatId, text, itemId: _chat.relatedItemId);
      _messageController.clear();
      setState(() {
        _chat = neoStore.chats.firstWhere((c) => c.id == widget.chatId);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _pickChatImage() async {
    if (!neoStore.canMessageUser(_chat.peerId)) {
      _showToast(
        'Вас заблоковано. Для звʼязку використовуйте чат з модератором.',
      );
      return;
      if (_isChatBlockedForMe()) {
        _showToast('Ви заблоковані у цьому чаті.');
        return;
      }
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (image == null) return;
      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0.0;
      });
      await neoStore.sendImageMessage(
        widget.chatId,
        image.path,
        itemId: _chat.relatedItemId,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _chat = neoStore.chats.firstWhere((c) => c.id == widget.chatId);
        _isUploadingImage = false;
        _uploadProgress = 0.0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        _uploadProgress = 0.0;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка під час вибору фото: $e')),
      );
    }
  }

  bool _isChatBlockedForMe() {
    final meId = neoStore.user?.uid;
    if (meId == null || meId.isEmpty) return false;
    return _chat.blockedUsers.contains(meId);
  }

  Future<void> _toggleChatBlock() async {
    final me = neoStore.user;
    if (me == null || !me.isModerator) return;
    if (_chat.peerId.isEmpty) return;

    final isBlocked = _chat.blockedUsers.contains(_chat.peerId);
    final title =
        isBlocked ? 'Розблокувати користувача?' : 'Заблокувати користувача?';
    final confirmText = isBlocked ? 'Розблокувати' : 'Заблокувати';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          isBlocked
              ? 'Користувач знову зможе писати вам у цьому чаті.'
              : 'Користувач не зможе писати вам у цьому чаті.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await neoStore.setChatUserBlocked(
      chatId: widget.chatId,
      userId: _chat.peerId,
      blocked: !isBlocked,
    );
  }

  void _showToast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _viewSellerProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerProfilePage(
          sellerId: _chat.peerId,
        ),
      ),
    );
  }

  Widget _buildItemPreview() {
    if (_chat.relatedItemId == null) return const SizedBox();

    final item =
        neoStore.items.firstWhere((item) => item.id == _chat.relatedItemId,
            orElse: () => Item(
                  id: '',
                  title: 'Оголошення видалено',
                  desc: '',
                  city: '',
                  category: '',
                  type: ItemType.exchange,
                  status: ItemStatus.pending,
                  likes: 0,
                  views: 0,
                  ownerId: '',
                  ownerName: '',
                  ownerEmail: '',
                  createdAt: DateTime.now(),
                  photoPaths: const [],
                  photoUrls: const [],
                ));

    final mainPhoto = item.mainPhoto;
    ImageProvider? previewImage;
    if (mainPhoto.isNotEmpty) {
      final uri = Uri.tryParse(mainPhoto);
      if (mainPhoto.startsWith('http') || mainPhoto.startsWith('https')) {
        previewImage = NetworkImage(mainPhoto);
      } else if (uri?.scheme == 'file') {
        previewImage = FileImage(File(uri!.toFilePath()));
      } else {
        previewImage = FileImage(File(mainPhoto));
      }
    }

    return GestureDetector(
      onTap: () {
        if (item.id.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NeoItemDetailPage(
                itemId: item.id,
                initialItem: item,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(51),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: previewImage != null
                    ? DecorationImage(
                        image: previewImage,
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: item.mainPhoto.isEmpty
                  ? Center(
                      child: Icon(
                        item.type.icon,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(128),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Обговорення щодо оголошення',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(153),
                    ),
                  ),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBackground() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface.withAlpha(255),
            cs.surfaceContainerHighest.withAlpha(235),
            const Color(0xFFF3EEE5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            left: -60,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 260,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  gradient: LinearGradient(
                    colors: [
                      NeoThemes.currentColor.withAlpha(70),
                      NeoThemes.currentNeon.withAlpha(30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -110,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    NeoThemes.currentNeon.withAlpha(70),
                    NeoThemes.currentNeon.withAlpha(5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 160,
            right: 30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(200),
                    Colors.white.withAlpha(40),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meId = neoStore.user?.uid ?? '';
    final isChatBlocked = meId.isNotEmpty && _chat.blockedUsers.contains(meId);
    final canSend = neoStore.canMessageUser(_chat.peerId) && !isChatBlocked;
    final blockMessage = isChatBlocked
        ? 'Ви заблоковані у цьому чаті.'
        : 'Вас заблоковано. Писати можна лише модератору.';
    final isModerator = neoStore.user?.isModerator == true;
    final isPeerBlocked = _chat.blockedUsers.contains(_chat.peerId);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _viewSellerProfile,
          child: Row(
            children: [
              _buildProfileImage(_chat.peerId, _chat.peerName),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chat.peerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (neoStore.sShowOnlineStatus)
                    _buildOnlineStatus(cs)
                  else
                    Text(
                      'Натисніть для перегляду профілю',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withAlpha(128),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildChatBackground(),
          Column(
            children: [
              _buildItemPreview(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: _chat.messages.length,
                  itemBuilder: (context, index) {
                    final message = _chat.messages[index];
                    final isMine = message.fromMe;
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final peerReadAt = _chat.lastRead[_chat.peerId];
                    final isReadByPeer = isMine &&
                        peerReadAt != null &&
                        !message.at.isAfter(peerReadAt);
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMine
                              ? LinearGradient(
                                  colors: [
                                    NeoThemes.currentColor.withAlpha(230),
                                    NeoThemes.currentColor.withAlpha(160),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    cs.surfaceContainerHighest,
                                    cs.surface,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMine
                                ? Colors.transparent
                                : cs.outline.withAlpha(51),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isMine ? 70 : 26),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                            if (!isDark)
                              BoxShadow(
                                color:
                                    Colors.white.withAlpha(isMine ? 90 : 120),
                                blurRadius: 8,
                                offset: const Offset(-2, -2),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (message.itemTitle != null && index == 0)
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: NeoThemes.currentColor.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: NeoThemes.currentColor.withAlpha(77),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_rounded,
                                      size: 16,
                                      color: NeoThemes.currentColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        message.itemTitle!,
                                        style: TextStyle(
                                          color: NeoThemes.currentColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (message.type == MessageType.image &&
                                (message.imageUrl?.isNotEmpty == true ||
                                    message.imagePath?.isNotEmpty == true))
                              GestureDetector(
                                onTap: () {
                                  final image = message.imageUrl ??
                                      message.imagePath ??
                                      '';
                                  if (image.isEmpty) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NeoImageFullScreen(
                                        images: [image],
                                        initialIndex: 0,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: (message.imageUrl?.isNotEmpty ==
                                              true &&
                                          (message.imageUrl!
                                                  .startsWith('http') ||
                                              message.imageUrl!
                                                  .startsWith('https')))
                                      ? CachedNetworkImage(
                                          imageUrl: message.imageUrl!,
                                          width: 220,
                                          height: 220,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: NeoThemes.currentColor,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                  Icons.broken_image_rounded),
                                        )
                                      : Image.file(
                                          File(
                                            _filePathFromImage(
                                              message.imageUrl ??
                                                  message.imagePath,
                                            ),
                                          ),
                                          width: 220,
                                          height: 220,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              )
                            else
                              SelectableText(
                                message.text,
                                style: TextStyle(
                                  color: isMine ? Colors.white : cs.onSurface,
                                  fontSize: 15,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${message.at.hour.toString().padLeft(2, '0')}:${message.at.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMine
                                        ? Colors.white.withAlpha(179)
                                        : cs.onSurface.withAlpha(128),
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    isReadByPeer
                                        ? Icons.done_all_rounded
                                        : Icons.done_rounded,
                                    size: 14,
                                    color: isReadByPeer
                                        ? Colors.white.withAlpha(220)
                                        : Colors.white.withAlpha(150),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isUploadingImage)
            Positioned(
              left: 16,
              right: 16,
              bottom: 74,
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          if (!canSend)
            Positioned(
              left: 16,
              right: 16,
              bottom: 74,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(90)),
                ),
                child: Text(
                  blockMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(
                      color: cs.outline.withAlpha(51),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        onPressed: canSend ? _pickChatImage : null,
                        icon: Icon(
                          Icons.photo_rounded,
                          color: canSend
                              ? cs.onSurface.withAlpha(179)
                              : cs.onSurface.withAlpha(80),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: cs.surfaceContainerHighest,
                        ),
                        child: TextField(
                          controller: _messageController,
                          enabled: canSend,
                          decoration: InputDecoration(
                            hintText: canSend
                                ? 'Напишіть повідомлення...'
                                : 'Повідомлення заблоковані',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          NeoThemes.getNeonDecoration(NeoThemes.currentColor),
                      child: IconButton(
                        onPressed: canSend ? _sendMessage : null,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        NEO CHATS
=========================== */

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month ${local.year} $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Доставлено';
      case 'failed':
        return 'Помилка';
      default:
        return 'У черзі';
    }
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return scheme.onSurface.withAlpha(128);
    }
  }

  Widget _buildAvatar(String userId, String fallbackName) {
    return FutureBuilder<String?>(
      future: neoStore.fetchUserProfileImageUrl(userId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url?.isNotEmpty == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: url!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, value) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeoThemes.currentColor,
                ),
              ),
              errorWidget: (context, value, error) {
                return _buildFallbackAvatar(fallbackName);
              },
            ),
          );
        }
        return _buildFallbackAvatar(fallbackName);
      },
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return CircleAvatar(
      backgroundColor: NeoThemes.currentColor.withAlpha(26),
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (context, _) {
        final notifications = neoStore.notifications;
        final hasUnread = notifications.any((n) => !n.read);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Сповіщення'),
            actions: [
              if (hasUnread)
                IconButton(
                  tooltip: 'Позначити все як прочитане',
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: () async {
                    await neoStore.markAllNotificationsRead();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Усі сповіщення позначено як прочитані'),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Text(
                    'Сповіщень поки немає',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final cs = Theme.of(context).colorScheme;
                    final statusText = _statusLabel(notification.status);
                    final statusColor = _statusColor(notification.status, cs);
                    final isModeration =
                        notification.action.startsWith('moderation');

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await neoStore.markNotificationRead(notification.id);
                        if (notification.chatId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChatDetailPage(chatId: notification.chatId),
                            ),
                          );
                        } else if (notification.itemId.isNotEmpty) {
                          final item = neoStore.items
                              .firstWhere((e) => e.id == notification.itemId,
                                  orElse: () => Item(
                                        id: '',
                                        title: 'Оголошення не знайдено',
                                        desc: '',
                                        city: '',
                                        category: '',
                                        type: ItemType.exchange,
                                        status: ItemStatus.pending,
                                        likes: 0,
                                        views: 0,
                                        ownerId: '',
                                        ownerName: '',
                                        ownerEmail: '',
                                        createdAt: DateTime.now(),
                                        photoPaths: const [],
                                        photoUrls: const [],
                                      ));
                          if (item.id.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Оголошення не знайдено'),
                              ),
                            );
                            return;
                          }
                          final isStatusFeedback =
                              notification.action == 'moderation_rejected' ||
                                  notification.action == 'moderation_revision';
                          if (isStatusFeedback) {
                            final isBlocked = neoStore.user?.isBlocked == true;
                            final isFinalRejected =
                                item.status == ItemStatus.rejected &&
                                    !item.needsRevision;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NeoEditItemPage(
                                  item: item,
                                  readOnly: isBlocked || isFinalRejected,
                                  moderationComment: notification.comment,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NeoItemDetailPage(
                                  itemId: item.id,
                                  initialItem: item,
                                ),
                              ),
                            );
                          }
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Чат для сповіщення не знайдено'),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: notification.read
                              ? null
                              : Border.all(
                                  color: NeoThemes.currentColor.withAlpha(128),
                                ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            isModeration
                                ? const CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Icon(Icons.gavel_rounded,
                                        color: Colors.white),
                                  )
                                : _buildAvatar(
                                    notification.fromUserId,
                                    notification.fromName,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.fromName,
                                    style: TextStyle(
                                      fontWeight: notification.read
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.body.isNotEmpty
                                        ? notification.body
                                        : notification.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurface.withAlpha(179),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime(notification.createdAt),
                                        style: TextStyle(
                                          color: cs.onSurface.withAlpha(128),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class NeoChats extends StatelessWidget {
  const NeoChats({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (context, _) {
        final meId = neoStore.user?.uid;
        final chats = neoStore.chats;

        Item? findItem(String? id) {
          if (id == null) return null;
          for (final item in neoStore.items) {
            if (item.id == id) return item;
          }
          return null;
        }

        bool isWantToGive(ChatThread chat) {
          if (meId == null) return false;
          final item = findItem(chat.relatedItemId);
          return item != null && item.ownerId == meId;
        }

        final wantGiveChats =
            chats.where((chat) => isWantToGive(chat)).toList();
        final wantGetChats =
            chats.where((chat) => !isWantToGive(chat)).toList();
        final wantGiveUnread = wantGiveChats.fold<int>(
            0, (sum, chat) => sum + max(0, chat.unread));
        final wantGetUnread =
            wantGetChats.fold<int>(0, (sum, chat) => sum + max(0, chat.unread));

        Widget buildChatList(List<ChatThread> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'Тут поки немає чатів',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final chat = list[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NeoChatTile(chat: chat),
              );
            },
          );
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface.withAlpha(230),
                      Theme.of(context).colorScheme.surface.withAlpha(153),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Повідомлення',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: NeoThemes.currentColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${neoStore.totalUnread} нових',
                            style: TextStyle(
                              color: NeoThemes.currentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Хочу отримати'),
                              if (wantGetUnread > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$wantGetUnread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Хочу віддати'),
                              if (wantGiveUnread > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$wantGiveUnread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      indicatorSize: TabBarIndicatorSize.tab,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    buildChatList(wantGetChats),
                    buildChatList(wantGiveChats),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class _NeoChatTile extends StatefulWidget {
  final ChatThread chat;

  const _NeoChatTile({required this.chat});

  @override
  State<_NeoChatTile> createState() => __NeoChatTileState();
}

class __NeoChatTileState extends State<_NeoChatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hover) {
    if (hover) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Widget _buildProfileImage() {
    return FutureBuilder<String?>(
      future: neoStore.fetchUserProfileImageUrl(widget.chat.peerId),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url?.isNotEmpty == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: url!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (context, value) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeoThemes.currentColor,
                ),
              ),
              errorWidget: (context, value, error) {
                return _buildDefaultPeerAvatar();
              },
            ),
          );
        }
        return _buildDefaultPeerAvatar();
      },
    );
  }

  Widget _buildDefaultPeerAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeoThemes.currentColor.withAlpha(204),
            NeoThemes.currentNeon.withAlpha(153),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          widget.chat.peerName.substring(0, 1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineIndicator(ColorScheme cs) {
    if (!neoStore.sShowOnlineStatus) return const SizedBox();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseService.firestore!
          .collection('users')
          .doc(widget.chat.peerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isOnline = data['online'] == true;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.green : cs.onSurface.withAlpha(90),
            border: Border.all(color: cs.surface, width: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastMessage = widget.chat.last;
    final lastPreview = lastMessage.type == MessageType.image
        ? 'Фото'
        : (lastMessage.text.isNotEmpty ? lastMessage.text : 'Повідомлення');

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(chatId: widget.chat.id),
            ),
          );
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: NeoThemes.getCardDecoration(context),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildProfileImage(),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _buildOnlineIndicator(cs),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.chat.peerName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${lastMessage.at.hour.toString().padLeft(2, '0')}:${lastMessage.at.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: cs.onSurface.withAlpha(128),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastPreview,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(179),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.chat.unread > 0)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: NeoThemes.currentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.chat.unread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===========================
        NEO FAVORITES
=========================== */

class NeoFavorites extends StatelessWidget {
  const NeoFavorites({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteItems = neoStore.items
        .where((item) => neoStore.isFav(item.id))
        .where((item) => item.status == ItemStatus.approved)
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface.withAlpha(230),
                    Theme.of(context).colorScheme.surface.withAlpha(153),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Обране',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${favoriteItems.length} збережених оголошень',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(153),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: favoriteItems.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 60,
                          color: Colors.grey.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Немає обраних оголошень',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = favoriteItems[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NeoItemDetailPage(
                                itemId: item.id,
                                initialItem: item,
                              ),
                            ),
                          );
                        },
                        child: _NeoFavoriteCard(item: item),
                      );
                    },
                    childCount: favoriteItems.length,
                  ),
                ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }
}

class _NeoFavoriteCard extends StatefulWidget {
  final Item item;

  const _NeoFavoriteCard({required this.item});

  @override
  State<_NeoFavoriteCard> createState() => __NeoFavoriteCardState();
}

class __NeoFavoriteCardState extends State<_NeoFavoriteCard> {
  bool _favorited = true;

  @override
  void initState() {
    super.initState();
    _favorited = neoStore.isFav(widget.item.id);
  }

  void _toggleFavorite() {
    setState(() => _favorited = !_favorited);
    neoStore.toggleFav(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: NeoThemes.getCardDecoration(context),
      child: Stack(
        children: [
          // Основное изображение
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: widget.item.getImageWidget(context, fit: BoxFit.cover),
            ),
          ),

          // Градиентный оверлей для лучшей читаемости текста
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(179),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),

          // Иконка избранного
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _favorited ? Icons.favorite_rounded : Icons.favorite_border,
                    color: _favorited ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // Информация об оголошенні внизу
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(220),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Text(
                      widget.item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Місто
                    const SizedBox(height: 6),
                    Text(
                      widget.item.city,
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/* ===========================
        NEO PROFILE
=========================== */

class NeoProfile extends StatefulWidget {
  const NeoProfile({super.key});

  @override
  State<NeoProfile> createState() => _NeoProfileState();
}

class _NeoProfileState extends State<NeoProfile> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupCityController = TextEditingController();
  bool _isLoginMode = true;
  bool _authLoading = false;
  String _authError = '';
  final GitHubUpdateService _updateService = GitHubUpdateService();
  bool _checkingForUpdate = false;
  bool _updateProgressVisible = false;

  @override
  void initState() {
    super.initState();
    if (neoStore.user != null) {
      _updateControllers();
    }
  }

  @override
  void didUpdateWidget(NeoProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (neoStore.user != null) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (neoStore.user != null) {
      _nameController.text = neoStore.user!.name;
      _cityController.text = neoStore.user!.city;
    }
  }

  Widget _buildProfileImage() {
    if (neoStore.user?.profileImageUrl?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: CachedNetworkImage(
          imageUrl: neoStore.user!.profileImageUrl!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NeoThemes.currentColor,
            ),
          ),
          errorWidget: (context, url, error) {
            return _buildDefaultAvatar();
          },
        ),
      );
    } else if (neoStore.user?.profileImagePath?.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.file(
          File(neoStore.user!.profileImagePath!),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        ),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeoThemes.currentColor,
            NeoThemes.currentNeon,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: NeoThemes.currentColor.withAlpha(77),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (image != null && neoStore.user != null) {
        await neoStore.updateProfile(profileImagePath: image.path);
        setState(() {});
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка під час вибору фото: $e'),
        ),
      );
    }
  }

  Future<void> _pickProfileCity() async {
    if (!_isEditing) return;
    final city = await showLocationPicker(
      context,
      initialCity: _cityController.text,
    );
    if (city != null) {
      setState(() => _cityController.text = city);
    }
  }

  Future<void> _pickSignupCity() async {
    final city = await showLocationPicker(
      context,
      initialCity: _signupCityController.text,
    );
    if (city != null) {
      setState(() => _signupCityController.text = city);
    }
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty || _cityController.text.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заповніть усі поля'),
        ),
      );
      return;
    }

    await neoStore.updateProfile(
      name: _nameController.text,
      city: _cityController.text,
    );

    setState(() {
      _isEditing = false;
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Профіль оновлено'),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (_authLoading) return;

    setState(() {
      _authLoading = true;
      _authError = '';
    });

    try {
      if (_isLoginMode) {
        if (_loginEmailController.text.isEmpty ||
            _loginPasswordController.text.isEmpty) {
          throw Exception('Заповніть усі поля');
        }

        await neoStore.login(
          email: _loginEmailController.text,
          password: _loginPasswordController.text,
        );
      } else {
        if (_signupNameController.text.isEmpty ||
            _signupEmailController.text.isEmpty ||
            _signupPasswordController.text.isEmpty ||
            _signupCityController.text.isEmpty) {
          throw Exception('Заповніть усі поля');
        }

        await neoStore.signup(
          name: _signupNameController.text,
          email: _signupEmailController.text,
          password: _signupPasswordController.text,
          city: _signupCityController.text,
        );
      }

      _loginEmailController.clear();
      _loginPasswordController.clear();
      _signupNameController.clear();
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupCityController.clear();

      setState(() {});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLoginMode
                ? 'Вхід виконано успішно!'
                : 'Реєстрація пройшла успішно!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        final rawMessage = e.toString().replaceFirst('Exception: ', '');
        _authError = rawMessage;

        if (e.toString().contains('wrong-password') ||
            e.toString().contains('Невірний пароль')) {
          _authError = 'Невірний пароль. Перевірте правильність введення.';
        } else if (e.toString().contains('user-not-found') ||
            e.toString().contains('Користувача не знайдено')) {
          _authError = 'Користувача з таким email не знайдено.';
        } else if (e.toString().contains('invalid-credential') ||
            e.toString().contains('invalid-credentials')) {
          _authError = 'Введені невірні дані.';
        } else if (e.toString().contains('email-already-in-use')) {
          _authError = 'Користувач з таким email вже існує.';
        } else if (e.toString().contains('network-request-failed') ||
            e.toString().contains('timeout') ||
            e.toString().contains('соединение')) {
          _authError =
              'Проблеми з підключенням до сервера. Перевірте інтернет.';
        } else if (e.toString().contains('invalid-email')) {
          _authError = 'Невірний формат email.';
        } else if (e.toString().contains('weak-password')) {
          _authError =
              'Пароль занадто слабкий. Використовуйте мінімум 6 символів.';
        }
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $_authError'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _authLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController(text: _loginEmailController.text);
    final email = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Відновлення пароля'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Надіслати'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseService.auth!.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лист для відновлення пароля надіслано'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _switchAuthMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _authError = '';
      _loginEmailController.clear();
      _loginPasswordController.clear();
      _signupNameController.clear();
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupCityController.clear();
    });
  }

  void _showTermsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsPage(),
      ),
    );
  }

  void _showPrivacyDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (context, _) {
        final user = neoStore.user;
        final isLoggedIn = user != null;
        return Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        NeoThemes.currentColor.withAlpha(77),
                        Theme.of(context).colorScheme.surface.withAlpha(153),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (!isLoggedIn)
                        _buildAuthForm()
                      else
                        _buildProfileHeader(),
                    ],
                  ),
                ),
              ),
              if (isLoggedIn && !_isEditing) ...[
                _buildLoggedInContent(),
              ],
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthForm() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NeoThemes.currentColor,
                NeoThemes.currentNeon,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NeoThemes.currentColor.withAlpha(77),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'FreeObmin',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _isLoginMode ? 'Вхід до акаунта' : 'Реєстрація',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _isLoginMode ? 'Увійдіть, щоб почати обмін' : 'Створіть новий акаунт',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (!_isLoginMode) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: NeoInput(
              controller: _signupNameController,
              hint: 'Імʼя',
              prefixIcon: Icons.person_rounded,
            ),
          ),
        ],
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: NeoInput(
            controller:
                _isLoginMode ? _loginEmailController : _signupEmailController,
            hint: 'Email',
            prefixIcon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: NeoInput(
            controller: _isLoginMode
                ? _loginPasswordController
                : _signupPasswordController,
            hint: 'Пароль',
            prefixIcon: Icons.lock_rounded,
            obscure: true,
          ),
        ),
        if (_isLoginMode)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              child: const Text('Забули пароль?'),
            ),
          ),
        if (!_isLoginMode) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: NeoInput(
              controller: _signupCityController,
              hint: 'Місто',
              prefixIcon: Icons.location_on_rounded,
              suffixIcon: Icons.keyboard_arrow_down_rounded,
              readOnly: true,
              onTap: _pickSignupCity,
            ),
          ),
        ],
        if (_authError.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _authError,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        NeoButton(
          text: _isLoginMode
              ? (_authLoading ? 'Вхід...' : 'Увійти')
              : (_authLoading ? 'Реєстрація...' : 'Зареєструватися'),
          onPressed: _handleAuth,
          loading: _authLoading,
          fullWidth: true,
          icon: _isLoginMode ? Icons.login_rounded : Icons.person_add_rounded,
        ),
        if (!_isLoginMode) ...[
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: cs.onSurface.withAlpha(153),
                fontSize: 12,
              ),
              children: [
                const TextSpan(
                  text:
                      'Натискаючи "Зареєструватися", ви погоджуєтеся з нашою ',
                ),
                TextSpan(
                  text: 'Політикою',
                  style: TextStyle(
                    color: NeoThemes.currentColor,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = _showPrivacyDialog,
                ),
                const TextSpan(text: ' і '),
                TextSpan(
                  text: 'Умовами',
                  style: TextStyle(
                    color: NeoThemes.currentColor,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLoginMode ? 'Ще немає акаунта?' : 'Вже є акаунт?',
              style: TextStyle(
                color: cs.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(width: 4),
            NeoTextButton(
              text: _isLoginMode ? 'Зареєструватися' : 'Увійти',
              onPressed: _switchAuthMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final user = neoStore.user!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickProfileImage : null,
          child: Stack(
            children: [
              _buildProfileImage(),
              if (_isEditing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(128),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isEditing)
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: NeoInput(
                  controller: _nameController,
                  hint: 'Імʼя',
                  prefixIcon: Icons.person_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: NeoInput(
                  controller: _cityController,
                  hint: 'Місто',
                  prefixIcon: Icons.location_on_rounded,
                  suffixIcon: Icons.keyboard_arrow_down_rounded,
                  readOnly: true,
                  onTap: _pickProfileCity,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeoButton(
                    text: 'Зберегти',
                    onPressed: _saveProfile,
                    icon: Icons.save_rounded,
                  ),
                  const SizedBox(width: 12),
                  NeoButton(
                    text: 'Скасувати',
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _updateControllers();
                      });
                    },
                    color: Colors.grey,
                    icon: Icons.close_rounded,
                  ),
                ],
              ),
            ],
          )
        else
          Column(
            children: [
              Text(
                user.name,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  color: cs.onSurface.withAlpha(153),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: user.isModerator
                      ? Colors.green.withAlpha(26)
                      : NeoThemes.currentColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: user.isModerator
                        ? Colors.green.withAlpha(77)
                        : NeoThemes.currentColor.withAlpha(77),
                  ),
                ),
                child: Text(
                  user.isAdmin
                      ? 'Адміністратор'
                      : user.isModerator
                          ? 'Модератор'
                          : 'Користувач',
                  style: TextStyle(
                    color: user.isModerator
                        ? Colors.green
                        : NeoThemes.currentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              NeoButton(
                text: 'Редагувати профіль',
                onPressed: () {
                  setState(() => _isEditing = true);
                },
                fullWidth: true,
                icon: Icons.edit_rounded,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoggedInContent() {
    final user = neoStore.user!;

    return SliverList(
      delegate: SliverChildListDelegate([
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: NeoThemes.getCardDecoration(context),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${user.itemsPosted}',
                    label: 'Оголошення',
                    icon: Icons.list_alt_rounded,
                  ),
                  _StatItem(
                    value: '${user.likes}',
                    label: 'Вподобання',
                    icon: Icons.favorite_rounded,
                  ),
                  _StatItem(
                    value: '${user.level}',
                    label: 'Рівень',
                    icon: Icons.star_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: user.itemsPosted / 10,
                backgroundColor: Colors.grey.withAlpha(26),
                color: NeoThemes.currentColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                'Прогрес: ${user.itemsPosted}/10 оголошень',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ..._buildProfileActions(),
      ]),
    );
  }

  List<Widget> _buildProfileActions() {
    final user = neoStore.user!;
    final pendingCount =
        user.isModerator ? neoStore.getPendingItems().length : 0;
    final complaintsCount = user.isModerator
        ? neoStore.complaints.where((c) => c.status == 'open').length
        : 0;
    final actions = [
      _ProfileItem(
        icon: Icons.list_alt_rounded,
        title: 'Мої оголошення',
        subtitle: 'Перегляд і редагування',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyItemsPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.emoji_events_rounded,
        title: 'Досягнення',
        subtitle: 'Отримані досягнення',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AchievementsPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.settings_rounded,
        title: 'Налаштування',
        subtitle: 'Теми й параметри',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NeoSettingsPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.system_update_rounded,
        title: 'Оновлення',
        subtitle: _checkingForUpdate
            ? 'Перевірка оновлень...'
            : 'Перевірити GitHub Releases',
        onTap: _checkForUpdates,
      ),
      if (user.isAdmin)
        _ProfileItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Адмін панель',
          subtitle: 'Керування та статистика',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardPage(),
              ),
            );
          },
        ),
      if (user.isModerator)
        _ProfileItem(
          icon: Icons.gavel_rounded,
          title: 'Модерація',
          subtitle: 'Перевірка оголошень',
          badgeCount: pendingCount + complaintsCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NeoModerationPage(),
              ),
            );
          },
        ),
      _ProfileItem(
        icon: Icons.help_rounded,
        title: 'Допомога',
        subtitle: 'Поширені питання',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.description_rounded,
        title: 'Умови',
        subtitle: 'Правила користування',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TermsPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.privacy_tip_rounded,
        title: 'Політика',
        subtitle: 'Конфіденційність',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivacyPage(),
            ),
          );
        },
      ),
      _ProfileItem(
        icon: Icons.logout_rounded,
        title: 'Вийти',
        subtitle: 'Завершити сесію',
        color: Colors.red,
        isLogout: true, // Указываем, что это кнопка выхода
        onTap: () {}, // Пустой колбек, так как логика в _LogoutButton
      ),
    ];

    return actions;
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdate) return;
    setState(() => _checkingForUpdate = true);
    _showUpdateProgress();
    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) return;
      _closeUpdateProgress();
      await _showUpdateDialog(result);
    } catch (error) {
      _closeUpdateProgress();
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'Не вдалося перевірити оновлення: ${error.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdate = false);
      }
    }
  }

  void _showUpdateProgress() {
    if (_updateProgressVisible) return;
    _updateProgressVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    ).then((_) => _updateProgressVisible = false);
  }

  void _closeUpdateProgress() {
    if (!_updateProgressVisible) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _updateProgressVisible = false;
  }

  Future<void> _showUpdateDialog(UpdateCheckResult result) {
    final notes = result.releaseNotes.trim();
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Оновлення'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Поточна версія: ${result.currentVersion}'),
              Text('Остання версія: ${result.latestVersion}'),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Опис релізу:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(180),
                    fontSize: 13,
                  ),
                ),
              ],
              if (Platform.isAndroid) ...[
                const SizedBox(height: 14),
                Text(
                  'Перед установкою APK відкрийте налаштування й дайте дозвіл '
                  'на встановлення з невідомих джерел.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openUrl(result.releaseUrl),
            child: const Text('Переглянути реліз'),
          ),
          if (result.updateAvailable && result.downloadUrl != null)
            TextButton(
              onPressed: () => _downloadAndInstallApk(result.downloadUrl!),
              child: const Text('Оновити'),
            ),
          if (Platform.isAndroid)
            TextButton(
              onPressed: _openInstallSettings,
              child: const Text('Налаштування установки'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрити'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося відкрити ${uri.toString()}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відкрити посилання: $error')),
      );
    }
  }

  Future<void> _openInstallSettings() async {
    if (!Platform.isAndroid) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
        data: 'package:${packageInfo.packageName}',
      );
      await intent.launch();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося відкрити налаштування: $error')),
      );
    }
  }

  Future<void> _downloadAndInstallApk(Uri apkUri) async {
    if (!Platform.isAndroid) {
      await _openUrl(apkUri);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/freeobmin_update.apk');
    double progress = 0;
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          dialogSetState = setState;
          return AlertDialog(
            title: const Text('Завантаження оновлення'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 12),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Dio().download(
        apkUri.toString(),
        file.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final value = received / total;
          if (dialogSetState != null) {
            dialogSetState!(() => progress = value);
          }
        },
      );

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося запустити встановлення: ${result.message}')),
        );
      }
    } catch (error) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка завантаження APK: $error')),
      );
    }
  }
}

/* ===========================
        MY ITEMS PAGE
=========================== */

class MyItemsPage extends StatefulWidget {
  const MyItemsPage({super.key});

  @override
  State<MyItemsPage> createState() => _MyItemsPageState();
}

class _MyItemsPageState extends State<MyItemsPage> {
  @override
  Widget build(BuildContext context) {
    final myItems = neoStore.myItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мої оголошення'),
      ),
      body: myItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 60,
                    color: Colors.grey.withAlpha(128),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Немає оголошень',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Створіть перше оголошення',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
                  ),
                  const SizedBox(height: 20),
                  NeoButton(
                    text: 'Створити оголошення',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NeoCreateItemPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: myItems.length,
              itemBuilder: (context, index) {
                final item = myItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _MyItemCard(item: item),
                );
              },
            ),
    );
  }
}

class _MyItemCard extends StatelessWidget {
  final Item item;

  const _MyItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBlocked = neoStore.user?.isBlocked == true;
    final needsRevision = item.needsRevision;
    final isFinalRejected =
        item.status == ItemStatus.rejected && !needsRevision;

    return Container(
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: item.getImageWidget(context, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.status.color.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: item.status.color.withAlpha(77),
                        ),
                      ),
                      child: Text(
                        item.status.label,
                        style: TextStyle(
                          color: item.status.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.desc,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(179),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: cs.onSurface.withAlpha(128),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.city,
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(128),
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.remove_red_eye_rounded,
                      size: 16,
                      color: cs.onSurface.withAlpha(128),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.views}',
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(128),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.likes}',
                      style: TextStyle(
                        color: cs.onSurface.withAlpha(128),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (!isBlocked && !isFinalRejected)
                      Expanded(
                        child: NeoButton(
                          text: 'Редагувати',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NeoEditItemPage(item: item),
                              ),
                            );
                          },
                          color: Colors.blue,
                        ),
                      )
                    else
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withAlpha(90)),
                          ),
                          child: Text(
                            isFinalRejected
                                ? 'Редагування недоступне: оголошення відхилено'
                                : 'Редагування недоступне: акаунт заблоковано',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoButton(
                        text: 'Видалити',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Видалити оголошення?'),
                              content: const Text(
                                  'Ви впевнені, що хочете видалити це оголошення?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Скасувати'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    neoStore.deleteItem(item.id);
                                    Navigator.pop(context);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Оголошення видалено'),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Видалити',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        ACHIEVEMENTS PAGE
=========================== */

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = neoStore.getUserAchievements();
    final unlockedCount = neoStore.unlockedAchievementsCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Достижения'),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NeoThemes.currentColor.withAlpha(77),
                    Theme.of(context).colorScheme.surface.withAlpha(153),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration:
                        NeoThemes.getNeonDecoration(NeoThemes.currentColor),
                    child: Center(
                      child: Text(
                        '$unlockedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Достижения',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$unlockedCount из ${achievements.length} разблокировано',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(153),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final achievement = achievements[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AchievementCard(achievement: achievement),
                  );
                },
                childCount: achievements.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = achievement.progress.toDouble();
    final target = achievement.target.toDouble();
    final percentage = (progress / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeoThemes.getCardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: achievement.unlocked
                  ? achievement.color.withAlpha(26)
                  : Colors.grey.withAlpha(26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: achievement.unlocked
                    ? achievement.color.withAlpha(77)
                    : Colors.grey.withAlpha(77),
              ),
            ),
            child: Center(
              child: Icon(
                achievement.icon,
                color: achievement.unlocked ? achievement.color : Colors.grey,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(153),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.withAlpha(26),
                  color: achievement.unlocked ? achievement.color : Colors.grey,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${achievement.progress}/${achievement.target}',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(153),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            achievement.unlocked
                ? Icons.check_circle_rounded
                : Icons.lock_rounded,
            color: achievement.unlocked ? achievement.color : Colors.grey,
          ),
        ],
      ),
    );
  }
}

/* ===========================
        SETTINGS PAGE
=========================== */

class NeoSettingsPage extends StatefulWidget {
  const NeoSettingsPage({super.key});

  @override
  State<NeoSettingsPage> createState() => _NeoSettingsPageState();
}

class _NeoSettingsPageState extends State<NeoSettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Ignore version loading errors.
    }
  }

  Future<void> _showFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (!mounted) return;

      if (token == null || token.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FCM токен не получен')),
        );
        return;
      }

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('FCM токен'),
          content: SelectableText(token),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Токен скопійовано')),
                );
              },
              child: const Text('Копіювати'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрити'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка отримання токена: $e')),
      );
    }
  }

  Future<void> _showOneSignalId() async {
    try {
      final subId = OneSignal.User.pushSubscription.id;
      if (!mounted) return;

      if (subId == null || subId.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OneSignal ID еще не получен')),
        );
        return;
      }

      final content = 'OneSignal ID: $subId';

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OneSignal ID'),
          content: SelectableText(content),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(context);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID скопійовано')),
                );
              },
              child: const Text('Копіювати'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрити'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка отримання OneSignal ID: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Налаштування'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Зовнішній вигляд',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: NeoThemes.getCardDecoration(context),
              child: Column(
                children: [
                  _SettingsItem(
                    title: 'Тема застосунку',
                    subtitle: 'Оберіть колірну тему',
                    trailing: Wrap(
                      spacing: 8,
                      children: NeoThemes.themeColors.map((color) {
                        final index = NeoThemes.themeColors.indexOf(color);
                        return GestureDetector(
                          onTap: () {
                            neoStore.changeTheme(index);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: neoStore.selectedThemeIndex == index
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  _SettingsItem(
                    title: 'Режим теми',
                    subtitle: 'Світла, темна або системна',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        _ThemeModeButton(
                          mode: 0,
                          icon: Icons.light_mode_rounded,
                          label: 'Світла',
                          isSelected: neoStore.selectedThemeMode == 0,
                        ),
                        _ThemeModeButton(
                          mode: 1,
                          icon: Icons.dark_mode_rounded,
                          label: 'Темна',
                          isSelected: neoStore.selectedThemeMode == 1,
                        ),
                        _ThemeModeButton(
                          mode: 2,
                          icon: Icons.settings_suggest_rounded,
                          label: 'Системна',
                          isSelected: neoStore.selectedThemeMode == 2,
                        ),
                      ],
                    ),
                  ),
                  if (neoStore.user?.isAdmin == true) ...[
                    const Divider(),
                    _SettingsItem(
                      title: 'FCM токен',
                      subtitle: 'Скопіювати токен пристрою',
                      trailing: TextButton(
                        onPressed: _showFcmToken,
                        child: const Text('Показати'),
                      ),
                    ),
                    _SettingsItem(
                      title: 'OneSignal ID',
                      subtitle: 'Перевірити підписку пристрою',
                      trailing: TextButton(
                        onPressed: _showOneSignalId,
                        child: const Text('Показати'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Сповіщення',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: NeoThemes.getCardDecoration(context),
              child: Column(
                children: [
                  _SettingsSwitch(
                    title: 'Push-сповіщення',
                    subtitle: 'Отримувати сповіщення про нові повідомлення',
                    value: neoStore.sNotifs,
                    onChanged: (value) {
                      neoStore.setSettings(notifs: value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Додатково',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: NeoThemes.getCardDecoration(context),
              child: Column(
                children: [
                  _SettingsSwitch(
                    title: 'Неон-ефекти',
                    subtitle: 'Використовувати неонові ефекти в інтерфейсі',
                    value: neoStore.sUseNeon,
                    neonGlow: true,
                    onChanged: (value) {
                      neoStore.setSettings(neon: value);
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  _SettingsSwitch(
                    title: 'Показувати онлайн статус',
                    subtitle: 'Показувати ваш онлайн статус іншим користувачам',
                    value: neoStore.sShowOnlineStatus,
                    onChanged: (value) {
                      neoStore.setSettings(showOnlineStatus: value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Небезпечна зона',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ці дії не можна скасувати',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(153),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeoButton(
                    text: 'Скинути всі дані',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Скинути всі дані?'),
                          content: const Text(
                              'Ця дія видалить усі локальні дані застосунку. Ви впевнені?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Скасувати'),
                            ),
                            TextButton(
                              onPressed: () {
                                neoStore.resetData();
                                Navigator.pop(context);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Дані скинуто'),
                                  ),
                                );
                              },
                              child: const Text(
                                'Скинути',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    color: Colors.red,
                    fullWidth: true,
                    icon: Icons.delete_forever_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            if (_appVersion.isNotEmpty)
              Center(
                child: Text(
                  'Версія застосунку: $_appVersion',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(140),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(153),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool neonGlow;

  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.neonGlow = false,
  });

  @override
  State<_SettingsSwitch> createState() => __SettingsSwitchState();
}

class __SettingsSwitchState extends State<_SettingsSwitch> {
  bool _value = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(_SettingsSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(153),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: widget.neonGlow && _value
                  ? [
                      BoxShadow(
                        color: NeoThemes.currentNeon.withAlpha(140),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Switch(
              value: _value,
              onChanged: (value) {
                setState(() {
                  _value = value;
                });
                widget.onChanged(value);
              },
              activeThumbColor: NeoThemes.currentColor,
              activeTrackColor: NeoThemes.currentColor.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final int mode;
  final IconData icon;
  final String label;
  final bool isSelected;

  const _ThemeModeButton({
    required this.mode,
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        neoStore.changeThemeMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NeoThemes.currentColor.withAlpha(26)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? NeoThemes.currentColor.withAlpha(77)
                : Colors.grey.withAlpha(77),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? NeoThemes.currentColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? NeoThemes.currentColor : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===========================
        HELP PAGE
=========================== */

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Допомога'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Поширені питання',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            const _HelpItem(
              question: 'Як створити оголошення?',
              answer:
                  'Натисніть кнопку "+" у центрі нижньої панелі навігації. Заповніть усі обовʼязкові поля, додайте фотографії та натисніть "Опублікувати".',
            ),
            const SizedBox(height: 16),
            const _HelpItem(
              question: 'Як звʼязатися з продавцем?',
              answer:
                  'На сторінці оголошення натисніть кнопку "Написати продавцю". Це відкриє чат з продавцем.',
            ),
            const SizedBox(height: 16),
            const _HelpItem(
              question: 'Як додати в обране?',
              answer:
                  'Натисніть на сердечко у правому верхньому куті картки оголошення на головній сторінці або на сторінці деталей оголошення.',
            ),
            const SizedBox(height: 16),
            const _HelpItem(
              question: 'Як змінити профіль?',
              answer:
                  'Перейдіть у розділ "Профіль" і натисніть "Редагувати профіль". Ви можете змінити імʼя, місто та фото профілю.',
            ),
            const SizedBox(height: 16),
            const _HelpItem(
              question: 'Що робити, якщо оголошення не публікується?',
              answer:
                  'Усі оголошення проходять модерацію. Зазвичай це займає до 24 годин. Якщо минуло більше часу, перевірте статус оголошення в розділі "Мої оголошення".',
            ),
            const SizedBox(height: 32),
            Text(
              'Контакти підтримки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: NeoThemes.getCardDecoration(context),
              child: const Column(
                children: [
                  _ContactItem(
                    icon: Icons.email_rounded,
                    title: 'Email',
                    value: 'support@neoobmin.com',
                  ),
                  Divider(),
                  _ContactItem(
                    icon: Icons.phone_rounded,
                    title: 'Телефон',
                    value: '+7 (999) 123-45-67',
                  ),
                  Divider(),
                  _ContactItem(
                    icon: Icons.language_rounded,
                    title: 'Веб-сайт',
                    value: 'www.neoobmin.com',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String question;
  final String answer;

  const _HelpItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              color: cs.onSurface.withAlpha(153),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ContactItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: NeoThemes.currentColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        TERMS PAGE
=========================== */

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Умови використання'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Умови використання FreeObmin',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Останнє оновлення: 1 січня 2024',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const _TermSection(
              title: '1. Загальні положення',
              content:
                  '1.1. Ці Умови використання регулюють відносини між вами та FreeObmin.\n\n'
                  '1.2. Використовуючи застосунок FreeObmin, ви погоджуєтеся з цими Умовами.',
            ),
            const SizedBox(height: 16),
            const _TermSection(
              title: '2. Реєстрація та акаунт',
              content:
                  '2.1. Для використання всіх функцій застосунку потрібна реєстрація.\n\n'
                  '2.2. Ви несете відповідальність за збереження своїх облікових даних.\n\n'
                  '2.3. Заборонено створювати кілька акаунтів.',
            ),
            const SizedBox(height: 16),
            const _TermSection(
              title: '3. Розміщення оголошень',
              content:
                  '3.1. Ви можете розміщувати оголошення про товари для обміну або дарування.\n\n'
                  '3.2. Заборонено розміщувати оголошення про заборонені товари.\n\n'
                  '3.3. Усі оголошення проходять модерацію.',
            ),
            const SizedBox(height: 16),
            const _TermSection(
              title: '4. Обмін товарами',
              content:
                  '4.1. FreeObmin є лише майданчиком для звʼязку користувачів.\n\n'
                  '4.2. Відповідальність за умови обміну несуть безпосередньо учасники угоди.\n\n'
                  '4.3. Рекомендуємо проводити угоди у безпечних місцях.',
            ),
            const SizedBox(height: 16),
            const _TermSection(
              title: '5. Відповідальність',
              content:
                  '5.1. FreeObmin не несе відповідальності за зміст оголошень.\n\n'
                  '5.2. FreeObmin не бере участі в угодах між користувачами.\n\n'
                  '5.3. У разі порушень ваш акаунт може бути заблокований.',
            ),
            const SizedBox(height: 16),
            const _TermSection(
              title: '6. Зміни умов',
              content:
                  '6.1. Ми залишаємо за собою право змінювати ці Умови.\n\n'
                  '6.2. Продовжуючи користуватися застосунком після змін, ви погоджуєтеся з новими Умовами.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeoThemes.currentColor.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NeoThemes.currentColor.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: NeoThemes.currentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Користуючись FreeObmin, ви підтверджуєте, що прочитали та погоджуєтеся з цими Умовами використання.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TermSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: cs.onSurface.withAlpha(153),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        PRIVACY PAGE
=========================== */

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Політика конфіденційності'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Політика конфіденційності FreeObmin',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Останнє оновлення: 1 січня 2024',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const _PrivacySection(
              title: '1. Інформація, що збирається',
              content:
                  '1.1. Під час реєстрації ми збираємо ваше імʼя, email і місто.\n\n'
                  '1.2. Під час розміщення оголошень ми збираємо інформацію про товари.\n\n'
                  '1.3. Ми збираємо технічну інформацію про ваш пристрій.',
            ),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: '2. Використання інформації',
              content:
                  '2.1. Ваша інформація використовується для роботи застосунку.\n\n'
                  '2.2. Ваш email використовується для сповіщень і відновлення акаунта.\n\n'
                  '2.3. Ми не продаємо ваші дані третім особам.',
            ),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: '3. Захист інформації',
              content:
                  '3.1. Ми використовуємо сучасні методи шифрування даних.\n\n'
                  '3.2. Ваші паролі зберігаються у зашифрованому вигляді.\n\n'
                  '3.3. Доступ до даних мають лише авторизовані співробітники.',
            ),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: '4. Фото та зображення',
              content:
                  '4.1. Фото товарів видно всім користувачам застосунку.\n\n'
                  '4.2. Фото профілю видно іншим користувачам.\n\n'
                  '4.3. Ви можете видалити свої фото в будь-який час.',
            ),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: '5. Ваші права',
              content:
                  '5.1. Ви можете запросити видалення вашого акаунта та даних.\n\n'
                  '5.2. Ви можете змінити свої дані в налаштуваннях профілю.\n\n'
                  '5.3. Ви можете відмовитися від отримання сповіщень.',
            ),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: '6. Контакти',
              content:
                  '6.1. З питань конфіденційності звертайтеся на privacy@neoobmin.com.\n\n'
                  '6.2. Ми відповідаємо на запити протягом 30 днів.\n\n'
                  '6.3. Ви також можете звʼязатися з нами через розділ "Допомога" в застосунку.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeoThemes.currentColor.withAlpha(26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NeoThemes.currentColor.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: NeoThemes.currentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ми цінуємо вашу довіру та робимо все можливе для захисту ваших даних.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String content;

  const _PrivacySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: cs.onSurface.withAlpha(153),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
        UI COMPONENTS
=========================== */

class NeoButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final Color? color;

  const NeoButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? NeoThemes.currentColor;

    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: btnColor.withAlpha(90),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if ((loading || icon != null) && text.isNotEmpty)
              const SizedBox(width: 12),
            if (text.isNotEmpty)
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NeoTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const NeoTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? NeoThemes.currentColor;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: btnColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class NeoInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  const NeoInput({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: cs.onSurface.withAlpha(128),
              )
            : null,
        suffixIcon: suffixIcon != null
            ? Icon(
                suffixIcon,
                color: cs.onSurface.withAlpha(128),
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: NeoThemes.currentColor.withAlpha(128),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}
/* ===========================
        EDIT ITEM PAGE
=========================== */

class NeoEditItemPage extends StatefulWidget {
  final Item item;
  final bool readOnly;
  final String? moderationComment;

  const NeoEditItemPage({
    super.key,
    required this.item,
    this.readOnly = false,
    this.moderationComment,
  });

  @override
  State<NeoEditItemPage> createState() => _NeoEditItemPageState();
}

class _NeoEditItemPageState extends State<NeoEditItemPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedCategory = 'Техника';
  ItemType _selectedType = ItemType.exchange;
  bool _loading = false;

  final List<String> _selectedImages = [];
  int _mainImageIndex = 0;

  final List<String> categories = [
    'Техника',
    'Одежда',
    'Дом',
    'Спорт',
    'Книги',
    'Другое'
  ];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickCity() async {
    if (widget.readOnly) return;
    final city = await showLocationPicker(
      context,
      initialCity: _cityController.text,
    );
    if (city != null) {
      setState(() => _cityController.text = city);
    }
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController.text = item.title;
    _descController.text = item.desc;
    _cityController.text = item.city;
    _selectedCategory = item.category;
    _selectedType = item.type;
    _selectedImages.addAll(item.photoUrls);
    for (final path in item.localImagePaths) {
      if (!_selectedImages.contains(path)) {
        _selectedImages.add(path);
      }
    }
    _mainImageIndex = item.mainImageIndex;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showToast('Можна вибрати не більше 5 фото');
      return;
    }

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final availableSlots = 5 - _selectedImages.length;
        final filesToAdd = pickedFiles.take(availableSlots).toList();

        setState(() {
          _selectedImages.addAll(filesToAdd.map((file) => file.path));
        });
      }
    } catch (e) {
      _showToast('Помилка під час вибору фото: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_mainImageIndex >= _selectedImages.length) {
        _mainImageIndex =
            _selectedImages.isNotEmpty ? _selectedImages.length - 1 : 0;
      }
    });
  }

  void _setMainImage(int index) {
    setState(() {
      _mainImageIndex = index;
    });
  }

  bool _isRemotePath(String path) {
    return path.startsWith('http');
  }

  ImageProvider _imageProvider(String path) {
    if (_isRemotePath(path)) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Widget _buildImageItem(int index) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: _imageProvider(_selectedImages[index]),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          if (index == _mainImageIndex)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _setMainImage(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  index == _mainImageIndex ? 'Головне' : 'Зробити головним',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (widget.readOnly) return;
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _cityController.text.isEmpty) {
      _showToast('Заповніть усі обовʼязкові поля');
      return;
    }

    if (_selectedImages.isEmpty) {
      _showToast('Додайте хоча б одне фото');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = neoStore.user;
      if (user == null) throw Exception('Не авторизовано');

      final uploadedUrls = await neoStore.uploadItemImages(_selectedImages);
      if (uploadedUrls.isEmpty) {
        _showToast('Не вдалося загрузить фото');
        return;
      }
      if (uploadedUrls.length < _selectedImages.length) {
        _showToast('Деякі фото не завантажилися');
      }

      final localPaths =
          _selectedImages.where((path) => !_isRemotePath(path)).toList();
      final mainIndex =
          _mainImageIndex < uploadedUrls.length ? _mainImageIndex : 0;

      final updatedItem = widget.item.copyWith(
        title: _titleController.text,
        desc: _descController.text,
        city: _cityController.text,
        category: _selectedCategory,
        type: _selectedType,
        // Отправляем на повторную модерацию
        status: ItemStatus.pending,
        photoUrls: uploadedUrls,
        localImagePaths: localPaths,
        mainImageIndex: mainIndex,
        updatedAt: DateTime.now(),
        needsRevision: false,
      );

      await neoStore.updateItem(updatedItem);

      if (!mounted) return;

      _showToast('Оголошення оновлено та надіслано на модерацію');
      Navigator.pop(context);
    } catch (e) {
      _showToast('Помилка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showToast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.moderationComment ?? widget.item.moderationComment;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.readOnly ? 'Перегляд оголошення' : 'Редагувати оголошення'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withAlpha(77)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        comment!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.readOnly &&
                widget.item.status == ItemStatus.rejected &&
                !widget.item.needsRevision)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Звернення відхилено, редагування недоступне.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(180),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Фотографии',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'До 5 фото. Перше фото буде головним.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return _buildImageItem(index);
                  },
                ),
              ),
            if (_selectedImages.length < 5)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: DottedBorder(
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  dashPattern: const [8, 4],
                  color: NeoThemes.currentColor.withAlpha(128),
                  child: InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainer
                            .withAlpha(77),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: NeoThemes.currentColor,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Додати фото',
                            style: TextStyle(
                              color: NeoThemes.currentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_selectedImages.length}/5',
                            style: TextStyle(
                              color: NeoThemes.currentColor.withAlpha(128),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Основна інформація',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            NeoInput(
              controller: _titleController,
              hint: 'Назва оголошення*',
              prefixIcon: Icons.title_rounded,
              enabled: !widget.readOnly,
            ),
            const SizedBox(height: 16),
            NeoInput(
              controller: _descController,
              hint: 'Описание*',
              prefixIcon: Icons.description_rounded,
              maxLines: 4,
              enabled: !widget.readOnly,
            ),
            const SizedBox(height: 16),
            NeoInput(
              controller: _cityController,
              hint: 'Місто*',
              prefixIcon: Icons.location_on_rounded,
              suffixIcon: Icons.keyboard_arrow_down_rounded,
              enabled: !widget.readOnly,
              readOnly: true,
              onTap: widget.readOnly ? null : _pickCity,
            ),
            const SizedBox(height: 24),
            Text(
              'Категорія',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: widget.readOnly
                      ? null
                      : (selected) {
                          setState(() => _selectedCategory = category);
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Тип оголошення',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TypeChoice(
                    type: ItemType.exchange,
                    selected: _selectedType == ItemType.exchange,
                    onTap: widget.readOnly
                        ? null
                        : () {
                            setState(() => _selectedType = ItemType.exchange);
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeChoice(
                    type: ItemType.gift,
                    selected: _selectedType == ItemType.gift,
                    onTap: widget.readOnly
                        ? null
                        : () {
                            setState(() => _selectedType = ItemType.gift);
                          },
                  ),
                ),
              ],
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withAlpha(77)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Після редагування оголошення буде надіслано на повторну модерацію',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              NeoButton(
                text: 'Зберегти зміни',
                onPressed: _handleUpdate,
                loading: _loading,
                fullWidth: true,
                icon: Icons.save_rounded,
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: NeoThemes.currentColor.withAlpha(26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: NeoThemes.currentColor.withAlpha(77),
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: NeoThemes.currentColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withAlpha(128),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final bool isLogout; // Добавляем флаг для кнопки выхода
  final int badgeCount;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.isLogout = false, // По умолчанию это не кнопка выхода
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final itemColor = color ?? NeoThemes.currentColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: isLogout
          ? _LogoutButton(
              // Используем специальную кнопку для выхода
              icon: icon,
              title: title,
              subtitle: subtitle,
              color: itemColor,
            )
          : _RegularProfileItem(
              // Обычная кнопка для других пунктов
              icon: icon,
              title: title,
              subtitle: subtitle,
              onTap: onTap,
              color: itemColor,
              cs: cs,
              badgeCount: badgeCount,
            ),
    );
  }
}

// Обычный пункт профілю
class _RegularProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final ColorScheme cs;
  final int badgeCount;

  const _RegularProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    required this.cs,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(77),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: cs.onSurface.withAlpha(153),
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurface.withAlpha(77),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      tileColor: cs.surfaceContainerHighest,
    );
  }
}

// Специальная кнопка выхода с подтверждением
class _LogoutButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _LogoutButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  State<_LogoutButton> createState() => __LogoutButtonState();
}

class __LogoutButtonState extends State<_LogoutButton> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      await neoStore.logout();

      // Показываем уведомление об успешном выходе
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ви успішно вийшли з акаунта'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка під час виходу: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Вихід з акаунта'),
        content: const Text('Ви впевнені, що хочете вийти з акаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
              _logout(); // Выполняем выход
            },
            child: const Text(
              'Вийти',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      onTap: _showLogoutDialog,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.color.withAlpha(77),
          ),
        ),
        child: Center(
          child: _isLoggingOut
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color,
                  ),
                )
              : Icon(
                  widget.icon,
                  color: widget.color,
                  size: 24,
                ),
        ),
      ),
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(
          color: cs.onSurface.withAlpha(153),
          fontSize: 12,
        ),
      ),
      trailing: _isLoggingOut
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.color,
              ),
            )
          : Icon(
              Icons.exit_to_app_rounded,
              color: widget.color,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      tileColor: cs.surfaceContainerHighest,
    );
  }
}

/* ===========================
        CREATE ITEM PAGE
=========================== */

class NeoCreateItemPage extends StatefulWidget {
  const NeoCreateItemPage({super.key});

  @override
  State<NeoCreateItemPage> createState() => _NeoCreateItemPageState();
}

class _NeoCreateItemPageState extends State<NeoCreateItemPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedCategory = 'Техника';
  ItemType _selectedType = ItemType.exchange;
  bool _loading = false;

  final List<String> _selectedImages = [];
  int _mainImageIndex = 0;

  final List<String> categories = [
    'Техника',
    'Одежда',
    'Дом',
    'Спорт',
    'Книги',
    'Другое'
  ];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickCity() async {
    final city = await showLocationPicker(
      context,
      initialCity: _cityController.text,
    );
    if (city != null) {
      setState(() => _cityController.text = city);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      _showToast('Можно выбрать не более 5 фото');
      return;
    }

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final availableSlots = 5 - _selectedImages.length;
        final filesToAdd = pickedFiles.take(availableSlots).toList();

        setState(() {
          _selectedImages.addAll(filesToAdd.map((file) => file.path));
        });
      }
    } catch (e) {
      _showToast('Помилка під час вибору фото: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_mainImageIndex >= _selectedImages.length) {
        _mainImageIndex =
            _selectedImages.isNotEmpty ? _selectedImages.length - 1 : 0;
      }
    });
  }

  void _setMainImage(int index) {
    setState(() {
      _mainImageIndex = index;
    });
  }

  bool _isRemotePath(String path) {
    return path.startsWith('http');
  }

  Widget _buildImageItem(int index) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: FileImage(File(_selectedImages[index])),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          if (index == _mainImageIndex)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _setMainImage(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  index == _mainImageIndex ? 'Главное' : 'Сделать главным',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (_loading) return;
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _cityController.text.isEmpty) {
      _showToast('Заполните все обязательные поля');
      return;
    }

    if (_selectedImages.isEmpty) {
      _showToast('Добавьте хотя бы одно фото');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = neoStore.user;
      if (user == null) throw Exception('Не авторизован');

      final uploadedUrls = await neoStore.uploadItemImages(_selectedImages);
      if (uploadedUrls.isEmpty) {
        _showToast('Не удалось загрузить фото');
        return;
      }
      if (uploadedUrls.length < _selectedImages.length) {
        _showToast('Некоторые фото не загрузились');
      }

      final localPaths =
          _selectedImages.where((path) => !_isRemotePath(path)).toList();
      final mainIndex =
          _mainImageIndex < uploadedUrls.length ? _mainImageIndex : 0;

      final newItem = Item(
        id: 'i_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text,
        desc: _descController.text,
        city: _cityController.text,
        category: _selectedCategory,
        type: _selectedType,
        status: user.isModerator ? ItemStatus.approved : ItemStatus.pending,
        likes: 0,
        views: 0,
        ownerId: user.uid,
        ownerName: user.name,
        ownerEmail: user.email,
        createdAt: DateTime.now(),
        photoPaths: const [],
        photoUrls: uploadedUrls,
        localImagePaths: localPaths,
        mainImageIndex: mainIndex,
      );

      await neoStore.addItem(newItem);

      if (!mounted) return;

      _showToast(user.isModerator
          ? 'Оголошення опубліковано!'
          : 'Оголошення надіслано на модерацію');
      Navigator.pop(context);
    } catch (e) {
      _showToast('Помилка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showToast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать объявление'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фотографии',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'До 5 фото. Первое фото будет главным.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return _buildImageItem(index);
                  },
                ),
              ),
            if (_selectedImages.length < 5)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: DottedBorder(
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  dashPattern: const [8, 4],
                  color: NeoThemes.currentColor.withAlpha(128),
                  child: InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainer
                            .withAlpha(77),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: NeoThemes.currentColor,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавить фото',
                            style: TextStyle(
                              color: NeoThemes.currentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_selectedImages.length}/5',
                            style: TextStyle(
                              color: NeoThemes.currentColor.withAlpha(128),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Основная информация',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            NeoInput(
              controller: _titleController,
              hint: 'Название объявления*',
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: 16),
            NeoInput(
              controller: _descController,
              hint: 'Описание*',
              prefixIcon: Icons.description_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            NeoInput(
              controller: _cityController,
              hint: 'Город*',
              prefixIcon: Icons.location_on_rounded,
              suffixIcon: Icons.keyboard_arrow_down_rounded,
              readOnly: true,
              onTap: _pickCity,
            ),
            const SizedBox(height: 24),
            Text(
              'Категория',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Тип объявления',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TypeChoice(
                    type: ItemType.exchange,
                    selected: _selectedType == ItemType.exchange,
                    onTap: () {
                      setState(() => _selectedType = ItemType.exchange);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeChoice(
                    type: ItemType.gift,
                    selected: _selectedType == ItemType.gift,
                    onTap: () {
                      setState(() => _selectedType = ItemType.gift);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            NeoButton(
              text: 'Опубликовать объявление',
              onPressed: _handleCreate,
              loading: _loading,
              fullWidth: true,
              icon: Icons.publish_rounded,
            ),
            const SizedBox(height: 20),
            if (neoStore.user?.isModerator == false)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withAlpha(77)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ваше объявление будет проверено модератором перед публикацией',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  final ItemType type;
  final bool selected;
  final VoidCallback? onTap;

  const _TypeChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? type.accent.withAlpha(26) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? type.accent : Colors.grey.withAlpha(77),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              type.icon,
              color: selected ? type.accent : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              type.label,
              style: TextStyle(
                color: selected ? type.accent : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===========================
        MODERATION PAGE
=========================== */

class NeoModerationPage extends StatefulWidget {
  const NeoModerationPage({super.key});

  @override
  State<NeoModerationPage> createState() => _NeoModerationPageState();
}

class _NeoModerationPageState extends State<NeoModerationPage> {
  @override
  Widget build(BuildContext context) {
    final pendingItems = neoStore.getPendingItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Модерація'),
      ),
      body: pendingItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 60,
                    color: Colors.green.withAlpha(128),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Немає оголошень для модерації',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: pendingItems.length,
              itemBuilder: (context, index) {
                final item = pendingItems[index];
                return _ModerationItemCard(item: item);
              },
            ),
    );
  }
}

class _ModerationItemCard extends StatelessWidget {
  final Item item;

  const _ModerationItemCard({required this.item});

  Future<String?> _askReason({
    required BuildContext context,
    required String title,
    required String confirmText,
    String hintText = 'Опишіть причину (необовʼязково)',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hintText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Скасувати'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _rejectItem(BuildContext context) async {
    final reason = await _askReason(
      context: context,
      title: 'Причина відхилення',
      confirmText: 'Відхилити',
    );
    if (reason == null) return;
    await neoStore.moderateItem(
      item.id,
      ItemStatus.rejected,
      comment: reason.isEmpty ? null : reason,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оголошення відхилено')),
    );
  }

  Future<void> _requestChanges(BuildContext context) async {
    final reason = await _askReason(
      context: context,
      title: 'Потрібні зміни',
      confirmText: 'Надіслати',
      hintText: 'Опишіть, що потрібно виправити',
    );
    if (reason == null || reason.isEmpty) return;
    await neoStore.moderateItem(
      item.id,
      ItemStatus.rejected,
      comment: reason,
      requestChanges: true,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Надіслано на доопрацювання')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NeoItemDetailPage(
              itemId: item.id,
              initialItem: item,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: NeoThemes.getCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: item.getImageWidget(context, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.desc,
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(179),
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: cs.onSurface.withAlpha(128),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.city,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(128),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.ownerName,
                        style: TextStyle(
                          color: cs.onSurface.withAlpha(179),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: NeoButton(
                          text: 'Відхилити',
                          onPressed: () => _rejectItem(context),
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeoButton(
                          text: 'На доопрацювання',
                          onPressed: () => _requestChanges(context),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  NeoButton(
                    text: 'Опублікувати',
                    onPressed: () {
                      neoStore.moderateItem(item.id, ItemStatus.approved);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Оголошення схвалено'),
                        ),
                      );
                    },
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showLocationPicker(
  BuildContext context, {
  String? initialCity,
  bool allowAll = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LocationPickerSheet(
      initialCity: initialCity,
      allowAll: allowAll,
    ),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  final String? initialCity;
  final bool allowAll;

  const _LocationPickerSheet({
    this.initialCity,
    this.allowAll = false,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  LocationData? _data;
  String? _selectedRegion;
  String? _selectedDistrict;
  LocationCity? _selectedCity;
  String _query = '';

  @override
  void initState() {
    super.initState();
    neoStore.locations.then((data) {
      if (!mounted) return;
      _data = data;
      _initSelection(data);
      setState(() {});
    });
  }

  void _initSelection(LocationData data) {
    if (_selectedRegion != null) return;

    final initial = widget.initialCity ?? '';
    final found = (initial.isNotEmpty && initial != 'Все')
        ? data.findCity(initial)
        : null;

    _selectedRegion =
        found?.region ?? (data.regions.isNotEmpty ? data.regions.first : null);

    if (_selectedRegion == null) return;

    final districts = data.districtsFor(_selectedRegion!);
    _selectedDistrict =
        found?.district ?? (districts.isNotEmpty ? districts.first : null);

    if (_selectedDistrict == null) return;

    final cities = data.citiesFor(_selectedRegion!, _selectedDistrict!);
    _selectedCity = found?.city ?? (cities.isNotEmpty ? cities.first : null);
  }

  void _updateRegion(String? value) {
    if (value == null || value == _selectedRegion || _data == null) return;
    setState(() {
      _selectedRegion = value;
      final districts = _data!.districtsFor(value);
      _selectedDistrict = districts.isNotEmpty ? districts.first : null;
      final cities = (_selectedDistrict != null)
          ? _data!.citiesFor(value, _selectedDistrict!)
          : const [];
      _selectedCity = cities.isNotEmpty ? cities.first : null;
      _query = '';
    });
  }

  void _updateDistrict(String? value) {
    if (value == null || value == _selectedDistrict || _data == null) return;
    setState(() {
      _selectedDistrict = value;
      final cities = _data!.citiesFor(_selectedRegion!, value);
      _selectedCity = cities.isNotEmpty ? cities.first : null;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _data == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Выберите город',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (widget.allowAll)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: NeoButton(
                      text: 'Все города',
                      onPressed: () => Navigator.pop(context, 'Все'),
                      color: Colors.grey,
                      icon: Icons.public_rounded,
                      fullWidth: true,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      _InlineDropdown(
                        label: 'Область',
                        items: _data!.regions,
                        value: _selectedRegion,
                        onChanged: (value) => _updateRegion(value),
                      ),
                      const SizedBox(height: 16),
                      _InlineDropdown(
                        label: 'Район',
                        items: _selectedRegion == null
                            ? const []
                            : _data!.districtsFor(_selectedRegion!),
                        value: _selectedDistrict,
                        onChanged: (value) => _updateDistrict(value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) {
                          setState(() => _query = value.trim().toLowerCase());
                        },
                        decoration: InputDecoration(
                          hintText: 'Поиск города',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: cs.onSurface.withAlpha(128),
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildCityList(),
                ),
              ],
            ),
    );
  }

  Widget _buildCityList() {
    if (_data == null || _selectedRegion == null || _selectedDistrict == null) {
      return const SizedBox.shrink();
    }

    final cities = _data!.citiesFor(_selectedRegion!, _selectedDistrict!);
    final filtered = _query.isEmpty
        ? cities
        : cities
            .where((city) => city.name.toLowerCase().contains(_query))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final city = filtered[index];
        final selected = _selectedCity?.name == city.name;
        return ListTile(
          onTap: () => Navigator.pop(context, city.name),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: selected
              ? NeoThemes.currentColor.withAlpha(26)
              : Colors.transparent,
          title: Text(city.name),
          subtitle: city.type.isNotEmpty ? Text(city.type) : null,
          trailing:
              selected ? const Icon(Icons.check_rounded) : const SizedBox(),
        );
      },
    );
  }
}

class _InlineDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final String? value;
  final ValueChanged<String> onChanged;

  const _InlineDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_InlineDropdown> createState() => _InlineDropdownState();
}

class _InlineDropdownState extends State<_InlineDropdown> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleMenu() {
    if (_entry != null) {
      _removeEntry();
      return;
    }

    if (widget.items.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final top = offset.dy + size.height + 6;
    final maxHeight = (screenHeight - top - 16).clamp(120, 320).toDouble();

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeEntry,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxHeight,
                    minWidth: size.width,
                  ),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = item == widget.value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          widget.onChanged(item);
                          _removeEntry();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? NeoThemes.currentColor.withAlpha(26)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_rounded,
                                  color: NeoThemes.currentColor,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final valueText =
        widget.value?.isNotEmpty == true ? widget.value! : 'Выберите';

    return CompositedTransformTarget(
      link: _link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _toggleMenu,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valueText,
                      style: TextStyle(
                        color: widget.value == null
                            ? cs.onSurface.withAlpha(128)
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurface.withAlpha(153),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;

  const _ComplaintCard({required this.complaint});

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month ${local.year} $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Прийнята';
      case 'rejected':
        return 'Відхилена';
      default:
        return 'Нова';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<Map<String, SessionUser?>> _loadUsers() async {
    final reporter = await neoStore.fetchUserById(complaint.reporterId);
    final reported = await neoStore.fetchUserById(complaint.reportedUserId);
    return {'reporter': reporter, 'reported': reported};
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Невідомо';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month ${local.year}';
  }

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: FutureBuilder<Map<String, SessionUser?>>(
            future: _loadUsers(),
            builder: (context, snapshot) {
              final reporter = snapshot.data?['reporter'];
              final reported = snapshot.data?['reported'];
              return ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Деталі скарги',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    complaint.reason.isNotEmpty
                        ? complaint.reason
                        : 'Причину не вказано',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(180),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (complaint.itemId?.isNotEmpty == true) ...[
                    Text(
                      'Оголошення',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline.withAlpha(51)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              complaint.itemTitle?.isNotEmpty == true
                                  ? complaint.itemTitle!
                                  : 'Без назви',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final itemId = complaint.itemId;
                              if (itemId == null || itemId.isEmpty) return;
                              final item = await neoStore.fetchItemById(itemId);
                              if (item == null) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NeoItemDetailPage(
                                    itemId: item.id,
                                    initialItem: item,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Відкрити'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Кого скаржаться',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _ComplaintUserInfo(
                    user: reported,
                    fallbackName: complaint.reportedUserName,
                    createdAtLabel: _formatDate(reported?.createdAt),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Хто скаржився',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _ComplaintUserInfo(
                    user: reporter,
                    fallbackName: complaint.reporterName,
                    createdAtLabel: _formatDate(reporter?.createdAt),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOpen = complaint.status == 'open';
    final isAccepted = complaint.status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: NeoThemes.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(complaint.status).withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusColor(complaint.status).withAlpha(90),
                  ),
                ),
                child: Text(
                  _statusLabel(complaint.status),
                  style: TextStyle(
                    color: _statusColor(complaint.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(complaint.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withAlpha(128),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Кого: ${complaint.reportedUserName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Від: ${complaint.reporterName}',
            style: TextStyle(
              color: cs.onSurface.withAlpha(153),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            complaint.reason.isNotEmpty
                ? complaint.reason
                : 'Причину не вказано',
            style: TextStyle(
              color: cs.onSurface.withAlpha(179),
              fontSize: 13,
            ),
          ),
          if (complaint.itemId?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Оголошення: ${complaint.itemTitle ?? 'Без назви'}',
              style: TextStyle(
                color: cs.onSurface.withAlpha(153),
                fontSize: 12,
              ),
            ),
          ],
          if (!isOpen && complaint.moderatorName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Модератор: ${complaint.moderatorName}',
              style: TextStyle(
                color: cs.onSurface.withAlpha(153),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showDetails(context),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('Деталі'),
            ),
          ),
          if (isOpen)
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    text: 'Відхилити',
                    onPressed: () {
                      neoStore.resolveComplaint(complaint, accept: false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скаргу відхилено')),
                      );
                    },
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoButton(
                    text: 'Прийняти скаргу',
                    onPressed: () async {
                      final controller = TextEditingController();
                      final reason = await showDialog<String?>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Причина блокування'),
                          content: TextField(
                            controller: controller,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Опишіть причину блокування',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('Скасувати'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                context,
                                controller.text.trim(),
                              ),
                              child: const Text('Прийняти'),
                            ),
                          ],
                        ),
                      );

                      if (reason == null || reason.isEmpty) return;
                      neoStore.resolveComplaint(
                        complaint,
                        accept: true,
                        moderatorReason: reason,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скаргу прийнято')),
                      );
                    },
                  ),
                ),
              ],
            )
          else if (isAccepted)
            FutureBuilder<bool>(
              future: neoStore.isUserBlocked(complaint.reportedUserId),
              builder: (context, snapshot) {
                final blocked = snapshot.data == true;
                if (!blocked) {
                  return Text(
                    'Користувача розблоковано',
                    style: TextStyle(
                      color: cs.onSurface.withAlpha(153),
                      fontSize: 12,
                    ),
                  );
                }
                return NeoButton(
                  text: 'Розблокувати',
                  onPressed: () {
                    neoStore.setUserBlocked(
                      userId: complaint.reportedUserId,
                      blocked: false,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Користувача розблоковано')),
                    );
                  },
                  color: Colors.orange,
                  icon: Icons.lock_open_rounded,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ComplaintUserInfo extends StatelessWidget {
  final SessionUser? user;
  final String fallbackName;
  final String createdAtLabel;

  const _ComplaintUserInfo({
    required this.user,
    required this.fallbackName,
    required this.createdAtLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = user?.name.isNotEmpty == true ? user!.name : fallbackName;
    final email = user?.email ?? '—';
    final phone = user?.phone?.isNotEmpty == true ? user!.phone! : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withAlpha(51)),
      ),
      child: Row(
        children: [
          if (user?.profileImageUrl?.isNotEmpty == true)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: user!.profileImageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (context, value, error) =>
                    const Icon(Icons.person_rounded),
              ),
            )
          else
            CircleAvatar(
              radius: 22,
              backgroundColor: NeoThemes.currentColor.withAlpha(180),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Телефон: $phone',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(140),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Реєстрація: $createdAtLabel',
                  style: TextStyle(
                    color: cs.onSurface.withAlpha(130),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
