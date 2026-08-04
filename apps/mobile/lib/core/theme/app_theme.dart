import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double pill = 100.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

/// Paleta de pista de tenis: verde profundo de fondo de pista como color
/// principal y lima de pelota como acento.
///
/// Antes esto era un naranja-rojo "energetico" heredado de cuando la app
/// se parecia a una de citas. Con el reposicionamiento (buscar con quien
/// jugar, no una cita) el verde lee como deporte y no como romance, y la
/// lima da un acento reconocible sin recurrir al rosa/rojo.
class LightModeColors {
  static const primary = Color(0xFF0E7A57); // Verde pista
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFB9F0D7);
  static const onPrimaryContainer = Color(0xFF002018);

  static const secondary = Color(0xFF1E293B); // Pizarra
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFDCE4EC);
  static const onSecondaryContainer = Color(0xFF111C2B);

  static const tertiary = Color(0xFFB9D63F); // Lima pelota de tenis
  static const onTertiary = Color(0xFF1F2600);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);

  static const surface = Color(0xFFF6F9F7);
  static const onSurface = Color(0xFF1A2320);
  static const background = Color(0xFFFFFFFF);
  static const outline = Color(0xFF8FA39B);
  static const surfaceVariant = Color(0xFFE1E9E4);
}

class DarkModeColors {
  static const primary = Color(0xFF6FDBAF);
  static const onPrimary = Color(0xFF003828);
  static const primaryContainer = Color(0xFF005B40);
  static const onPrimaryContainer = Color(0xFF8CF8CA);

  static const secondary = Color(0xFFBCC7D6);
  static const onSecondary = Color(0xFF232F3E);
  static const secondaryContainer = Color(0xFF3A4758);
  static const onSecondaryContainer = Color(0xFFD8E2F9);

  static const tertiary = Color(0xFFC7E356);
  static const onTertiary = Color(0xFF2A3300);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);

  static const surface = Color(0xFF101614);
  static const onSurface = Color(0xFFE0E6E2);
  static const background = Color(0xFF080C0B);
  static const outline = Color(0xFF677B73);
  static const surfaceVariant = Color(0xFF2A3531);
}

class FontSizes {
  static const double displayLarge = 48.0;
  static const double displayMedium = 40.0;
  static const double displaySmall = 32.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
}

/// Extraidos a constantes para que los temas de componentes de abajo
/// puedan derivarse del mismo esquema en vez de repetir colores sueltos.
const _lightScheme = ColorScheme.light(
  primary: LightModeColors.primary,
  onPrimary: LightModeColors.onPrimary,
  primaryContainer: LightModeColors.primaryContainer,
  onPrimaryContainer: LightModeColors.onPrimaryContainer,
  secondary: LightModeColors.secondary,
  onSecondary: LightModeColors.onSecondary,
  secondaryContainer: LightModeColors.secondaryContainer,
  onSecondaryContainer: LightModeColors.onSecondaryContainer,
  tertiary: LightModeColors.tertiary,
  onTertiary: LightModeColors.onTertiary,
  error: LightModeColors.error,
  onError: LightModeColors.onError,
  surface: LightModeColors.surface,
  onSurface: LightModeColors.onSurface,
  onSurfaceVariant: LightModeColors.outline,
  surfaceContainerHighest: LightModeColors.surfaceVariant,
  outline: LightModeColors.outline,
);

const _darkScheme = ColorScheme.dark(
  primary: DarkModeColors.primary,
  onPrimary: DarkModeColors.onPrimary,
  primaryContainer: DarkModeColors.primaryContainer,
  onPrimaryContainer: DarkModeColors.onPrimaryContainer,
  secondary: DarkModeColors.secondary,
  onSecondary: DarkModeColors.onSecondary,
  secondaryContainer: DarkModeColors.secondaryContainer,
  onSecondaryContainer: DarkModeColors.onSecondaryContainer,
  tertiary: DarkModeColors.tertiary,
  onTertiary: DarkModeColors.onTertiary,
  error: DarkModeColors.error,
  onError: DarkModeColors.onError,
  surface: DarkModeColors.surface,
  onSurface: DarkModeColors.onSurface,
  onSurfaceVariant: DarkModeColors.outline,
  surfaceContainerHighest: DarkModeColors.surfaceVariant,
  outline: DarkModeColors.outline,
);

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: _lightScheme,
  scaffoldBackgroundColor: LightModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: LightModeColors.surfaceVariant, width: 1),
    ),
    color: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.primary,
      foregroundColor: LightModeColors.onPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: FontSizes.labelLarge,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.primary,
      side: const BorderSide(color: LightModeColors.primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: FontSizes.labelLarge,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: LightModeColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    hintStyle: GoogleFonts.inter(color: LightModeColors.outline),
  ),
  navigationBarTheme: _navigationBarTheme(_lightScheme),
  chipTheme: _chipTheme(_lightScheme),
  filledButtonTheme: _filledButtonTheme(_lightScheme),
  bottomSheetTheme: _bottomSheetTheme(_lightScheme),
  snackBarTheme: _snackBarTheme(_lightScheme),
  dialogTheme: _dialogTheme(_lightScheme),
  dividerTheme: const DividerThemeData(
    space: 1,
    thickness: 1,
    color: LightModeColors.surfaceVariant,
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    ),
  ),
  textTheme: _buildTextTheme(),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: _darkScheme,
  scaffoldBackgroundColor: DarkModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.onSurface,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: DarkModeColors.surfaceVariant, width: 1),
    ),
    color: DarkModeColors.surface,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.primary,
      foregroundColor: DarkModeColors.onPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: FontSizes.labelLarge,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.surfaceVariant,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    hintStyle: GoogleFonts.inter(color: DarkModeColors.outline),
  ),
  navigationBarTheme: _navigationBarTheme(_darkScheme),
  chipTheme: _chipTheme(_darkScheme),
  filledButtonTheme: _filledButtonTheme(_darkScheme),
  bottomSheetTheme: _bottomSheetTheme(_darkScheme),
  snackBarTheme: _snackBarTheme(_darkScheme),
  dialogTheme: _dialogTheme(_darkScheme),
  dividerTheme: const DividerThemeData(
    space: 1,
    thickness: 1,
    color: DarkModeColors.surfaceVariant,
  ),
  listTileTheme: const ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    ),
  ),
  textTheme: _buildTextTheme(),
);

/// Temas de componentes compartidos entre claro y oscuro.
///
/// Antes cada `ThemeData` declaraba los suyos a mano y solo cubrian
/// botones e inputs, asi que chips, navegacion, hojas y snackbars salian
/// con el aspecto por defecto de Material y desentonaban. Al construirlos
/// desde el `ColorScheme` los dos modos no pueden desincronizarse.
NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
  return NavigationBarThemeData(
    backgroundColor: scheme.surface,
    indicatorColor: scheme.primaryContainer,
    elevation: 0,
    height: 68,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 24,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      );
    }),
    labelTextStyle: WidgetStateProperty.all(
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

ChipThemeData _chipTheme(ColorScheme scheme) {
  return ChipThemeData(
    backgroundColor: scheme.surface,
    selectedColor: scheme.primaryContainer,
    checkmarkColor: scheme.onPrimaryContainer,
    side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    labelStyle: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w500,
    ),
  );
}

FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      textStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: FontSizes.labelLarge,
      ),
    ),
  );
}

BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) {
  return BottomSheetThemeData(
    backgroundColor: scheme.surface,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
    ),
  );
}

SnackBarThemeData _snackBarTheme(ColorScheme scheme) {
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: scheme.secondary,
    contentTextStyle: GoogleFonts.inter(
      color: scheme.onSecondary,
      fontSize: FontSizes.bodyMedium,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );
}

DialogThemeData _dialogTheme(ColorScheme scheme) {
  return DialogThemeData(
    backgroundColor: scheme.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );
}

TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: GoogleFonts.poppins(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.bold,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.bold,
      height: 1.1,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    headlineLarge: GoogleFonts.poppins(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    titleLarge: GoogleFonts.poppins(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.normal,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );
}
