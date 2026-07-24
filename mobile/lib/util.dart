import 'package:intl/intl.dart';

/// Formatowanie kwot: 123456 groszy -> "1 234,56 zł".
String formatMoney(int grosze) {
  final sign = grosze < 0 ? '-' : '';
  final abs = grosze.abs();
  final zl = abs ~/ 100;
  final gr = abs % 100;
  final zlStr = zl.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
  return '$sign$zlStr,${gr.toString().padLeft(2, '0')} zł';
}

/// "12,50" / "12.50" / "12" -> grosze (1250). null gdy nie da się sparsować.
int? parseMoney(String input) {
  final cleaned = input
      .trim()
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll('zł', '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

String dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String monthStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime mondayOf(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));

String todayStr() => dateStr(DateTime.now());

String prettyDate(String yyyyMmDd) {
  final d = DateTime.parse(yyyyMmDd);
  return DateFormat('EEE, d MMM', 'pl').format(d);
}

String prettyDateTime(DateTime d) => DateFormat('EEE, d MMM HH:mm', 'pl').format(d);

String timeOf(DateTime d) => DateFormat('HH:mm').format(d);

const mealTypes = [
  'sniadanie',
  'drugie_sniadanie',
  'obiad',
  'podwieczorek',
  'kolacja',
  'przekaska',
];

const mealTypeLabels = {
  'sniadanie': 'Śniadanie',
  'drugie_sniadanie': 'II śniadanie',
  'obiad': 'Obiad',
  'podwieczorek': 'Podwieczorek',
  'kolacja': 'Kolacja',
  'przekaska': 'Przekąska',
};

const mealTypeEmoji = {
  'sniadanie': '🍳',
  'drugie_sniadanie': '🥪',
  'obiad': '🍲',
  'podwieczorek': '🍰',
  'kolacja': '🥗',
  'przekaska': '🍎',
};

const txCategories = [
  'jedzenie',
  'dom',
  'rachunki',
  'transport',
  'zdrowie',
  'uroda',
  'ubrania',
  'dzieci',
  'zwierzaki',
  'rozrywka',
  'prezenty',
  'inne',
];

const categoryEmoji = {
  'jedzenie': '🛒',
  'dom': '🏠',
  'rachunki': '🧾',
  'transport': '🚗',
  'zdrowie': '💊',
  'uroda': '💅',
  'ubrania': '👗',
  'dzieci': '🧸',
  'zwierzaki': '🐾',
  'rozrywka': '🎉',
  'prezenty': '🎁',
  'inne': '✨',
};

const repeatLabels = {
  'none': 'Nie powtarza się',
  'daily': 'Codziennie',
  'weekly': 'Co tydzień',
  'monthly': 'Co miesiąc',
};

/// Kolejność posiłków przy sortowaniu wpisów.
int mealOrder(String mealType) {
  final idx = mealTypes.indexOf(mealType);
  return idx < 0 ? 99 : idx;
}
