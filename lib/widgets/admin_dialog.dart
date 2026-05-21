import 'package:flutter/material.dart';
import '../screens/admin_shared.dart';

AlertDialog adminAlertDialog({
  required Widget title,
  required Widget content,
  List<Widget>? actions,
  MainAxisAlignment actionsAlignment = MainAxisAlignment.end,
  Color? backgroundColor,
  double borderRadius = 16,
}) {
  return AlertDialog(
    backgroundColor: backgroundColor ?? AdminTheme.cardColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
    title: title,
    content: content,
    actionsAlignment: actionsAlignment,
    actions: actions ?? [],
  );
}
