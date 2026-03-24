import 'package:flutter_riverpod/flutter_riverpod.dart';

// Хранит индекс активной вкладки
final navigationIndexProvider = StateProvider<int>((ref) => 0);