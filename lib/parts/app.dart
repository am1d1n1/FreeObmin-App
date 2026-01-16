part of '../main.dart';

class FreeObminApp extends StatelessWidget {
  const FreeObminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: neoStore,
      builder: (_, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FreeObmin',
          navigatorKey: _rootNavKey,
          themeMode: neoStore.themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const NeoRoot(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final color = NeoThemes.currentColor;
    const surface = Color(0xFFFFFFFF);
    const background = Color(0xFFF1F4F6);
    const onSurface = Color(0xFF12161C);

    final baseScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Brightness.light,
    ).copyWith(
      surface: surface,
      surfaceContainerHighest: const Color(0xFFE8EDF1),
      surfaceContainer: const Color(0xFFF2F5F7),
      onSurface: onSurface,
      outline: const Color(0xFFD7DEE6),
      outlineVariant: const Color(0xFFE3E9EF),
    );

    final textTheme = GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8EF)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseScheme.surfaceContainerHighest,
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
            color: color.withAlpha(140),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: color.withAlpha(100)),
          textStyle: textTheme.labelLarge,
          backgroundColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: color,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconTheme: const IconThemeData(size: 22, color: onSurface),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4EAF0),
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: color.withAlpha(20),
        deleteIconColor: color,
        selectedColor: color.withAlpha(50),
        secondarySelectedColor: color.withAlpha(80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withAlpha(80)),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: color),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        brightness: Brightness.light,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        tileColor: baseScheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: baseScheme.surface,
        selectedItemColor: color,
        unselectedItemColor: onSurface.withAlpha(140),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: color,
        unselectedLabelColor: onSurface.withAlpha(140),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withAlpha(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final color = NeoThemes.currentColor;
    const surface = Color(0xFF151A21);
    const background = Color(0xFF0E1116);
    const onSurface = Color(0xFFE6ECF2);

    final baseScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      surfaceContainerHighest: const Color(0xFF1C2430),
      surfaceContainer: const Color(0xFF191F2A),
      onSurface: onSurface,
      outline: const Color(0xFF2A3442),
      outlineVariant: const Color(0xFF202834),
    );

    final textTheme = GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF273141)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseScheme.surfaceContainerHighest,
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
            color: color.withAlpha(140),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: color.withAlpha(100)),
          textStyle: textTheme.labelLarge,
          backgroundColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: color,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconTheme: const IconThemeData(size: 22, color: onSurface),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF232C37),
        thickness: 1,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: color.withAlpha(34),
        deleteIconColor: color,
        selectedColor: color.withAlpha(70),
        secondarySelectedColor: color.withAlpha(100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withAlpha(80)),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: color),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        brightness: Brightness.dark,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        tileColor: baseScheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: baseScheme.surface,
        selectedItemColor: color,
        unselectedItemColor: onSurface.withAlpha(140),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: color,
        unselectedLabelColor: onSurface.withAlpha(140),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withAlpha(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/* ===========================
        NEO THEMES
=========================== */

class NeoThemes {
  static final List<Color> themeColors = [
    const Color(0xFF18A957), // Avito green
    const Color(0xFF2A6DF4), // Avito blue
    const Color(0xFF23B7A8), // Teal
    const Color(0xFF8BC34A), // Lime
    const Color(0xFF00A3FF), // Sky
    const Color(0xFFF5A524), // Amber
    const Color(0xFFE53935), // Red
    const Color(0xFF7E57C2), // Violet
  ];

  static final List<Color> neonColors = [
    const Color(0xFF2ECC71), // Brighter green
    const Color(0xFF5C8DFF), // Brighter blue
    const Color(0xFF44CFC1), // Brighter teal
    const Color(0xFFA7D971), // Brighter lime
    const Color(0xFF4CC3FF), // Brighter sky
    const Color(0xFFFFC55A), // Brighter amber
    const Color(0xFFFF6F6B), // Brighter red
    const Color(0xFFA184FF), // Brighter violet
  ];

  static final List<String> themeNames = [
    'Индиго',
    'Фиолет',
    'Рожевий',
    'Изумруд',
    'Лазурь',
    'Янтарь',
    'Червоний',
    'Циан'
  ];

  static Color get currentColor => themeColors[neoStore.selectedThemeIndex];
  static Color get currentNeon => neonColors[neoStore.selectedThemeIndex];

  static Gradient getPrimaryGradient(Color color) {
    return LinearGradient(
      colors: [
        color.withAlpha(220),
        color.withAlpha(140),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 1.0],
    );
  }

  static Gradient getCardGradient(bool isDark) {
    return LinearGradient(
      colors: isDark
          ? [
              const Color(0xFF18202B),
              const Color(0xFF141A22),
            ]
          : [
              const Color(0xFFFFFFFF),
              const Color(0xFFF2F5F7),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static Gradient getBlurGradient(bool isDark) {
    return LinearGradient(
      colors: isDark
          ? [
              Colors.black.withAlpha(77),
              Colors.black.withAlpha(26),
            ]
          : [
              Colors.white.withAlpha(204),
              Colors.white.withAlpha(77),
            ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static BoxDecoration getAppBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = currentColor;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [
                const Color(0xFF0E1116),
                const Color(0xFF141A22),
                color.withAlpha(28),
              ]
            : [
                const Color(0xFFF1F4F6),
                const Color(0xFFF7F9FB),
                color.withAlpha(20),
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static BoxDecoration getCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: cs.outline.withAlpha(isDark ? 128 : 160),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 80 : 20),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration getBlurDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      gradient: getBlurGradient(isDark),
      borderRadius: BorderRadius.circular(20),
    );
  }

  static BoxDecoration getNeonDecoration(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withAlpha(170),
          color.withAlpha(90),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: color.withAlpha(110),
          blurRadius: 18,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration getGlassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark
          ? const Color(0xFF151A21).withAlpha(210)
          : const Color(0xFFFFFFFF).withAlpha(230),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(40) : Colors.black.withAlpha(15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 70 : 18),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

