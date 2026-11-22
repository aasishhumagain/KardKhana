import 'package:flutter/foundation.dart';

abstract class TableSession extends ChangeNotifier {
  Map<String, dynamic> get view;

  void send(String action, [Map<String, Object?> fields = const {}]);
}
