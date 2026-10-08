import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Helpers de formato en español y fecha dd/MM/yyyy.
class Formatters {
  static final DateFormat dateFmt =
      DateFormat(AppConstants.datePattern, 'es');
  static final DateFormat dateTimeFmt =
      DateFormat(AppConstants.dateTimePattern, 'es');

  static String date(DateTime d) => dateFmt.format(d);
  static String dateTime(DateTime d) => dateTimeFmt.format(d);

  static Color colorFromHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  static String colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

/// Muestra un SnackBar simple.
void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Diálogo de confirmación genérico. Devuelve true si confirma.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}
