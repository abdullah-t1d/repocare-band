import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  // Clean URLs (/live instead of /#/live).
  usePathUrlStrategy();
  runApp(const ProviderScope(child: RepoCareApp()));
}
