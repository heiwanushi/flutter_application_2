import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;

import '../../data/models/note.dart';
import '../../data/models/structured_note_data.dart';
import '../services/settings_service.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref);
});

class GeminiService {
  final Ref _ref;
  late final GenerativeModel _primaryModel;
  final String _modelName = 'gemini-2.5-flash-lite';

  GeminiService(this._ref) {
    _primaryModel = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<String?> _generateWithRetry(String prompt) async {
    final usePersonalKey = _ref.read(useFallbackApiKeyProvider);
    final personalKey = _ref.read(fallbackApiKeyProvider);

    if (usePersonalKey && personalKey != null && personalKey.isNotEmpty) {
      dev.log('GeminiService: Использование персонального ключа (AI Studio)');
      return _generateViaAIStudio(prompt, personalKey);
    } else {
      dev.log('GeminiService: Использование стандартного сервиса (Firebase)');
      return _generateViaFirebase(prompt);
    }
  }

  Future<String?> _generateViaFirebase(String prompt) async {
    try {
      final response = await _primaryModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text;
    } catch (e) {
      dev.log('GeminiService: Ошибка Firebase: $e');
      rethrow;
    }
  }

  Future<String?> _generateViaAIStudio(String prompt, String apiKey) async {
    try {
      final fallbackModel = google_ai.GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: google_ai.GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final response = await fallbackModel.generateContent([
        google_ai.Content.text(prompt),
      ]);
      return response.text;
    } catch (e) {
      dev.log('GeminiService: Ошибка AI Studio: $e');
      rethrow;
    }
  }

  Future<String?> _processText(String content, String instruction) async {
    try {
      if (content.trim().isEmpty) return null;

      final prompt =
          '''
$instruction

Верни ответ СТРОГО в формате JSON:
{
  "result": "текст обработанной заметки"
}

Текст для обработки:
$content
''';

      final text = await _generateWithRetry(prompt);
      if (text == null || text.isEmpty) return null;

      final jsonStr = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return jsonMap['result'] as String?;
    } catch (e) {
      throw Exception('Ошибка Gemini API: $e');
    }
  }

  Future<String?> improveText(String content) async {
    return _processText(
      content,
      'Ты — профессиональный редактор. Улучши стиль текста, сделай его более ясным, профессиональным и приятным для чтения. Сохрани оригинальный смысл и детали. Исправь опечатки.',
    );
  }

  Future<String?> checkGrammar(String content) async {
    return _processText(
      content,
      'Проверь текст на наличие грамматических, пунктуационных и орфографических ошибок. Исправь их, максимально сохраняя авторский стиль и структуру текста.',
    );
  }

  Future<String?> summarize(String content) async {
    return _processText(
      content,
      'Сократи текст до самых главных мыслей. Создай краткую выжимку (саммари), которая передает суть, но в разы короче оригинала. Используй буллиты, если это уместно.',
    );
  }

  Future<StructuredNoteData?> structureNote(
    String rawContent, {
    List<NoteContact> userContacts = const [],
    List<String> existingFolders = const [],
  }) async {
    try {
      if (rawContent.trim().isEmpty) return null;

      final now = DateTime.now();

      String contactsContext = '';
      if (userContacts.isNotEmpty) {
        final simplified = userContacts
            .map((c) => {'name': c.name, 'phone': c.phoneNumber})
            .toList();
        contactsContext =
            '\nСПРАВОЧНИК КОНТАКТОВ ПОЛЬЗОВАТЕЛЯ (используй для сопоставления):\n${jsonEncode(simplified)}\n';
      }

      final prompt =
          '''
Текущая дата и время системы: ${now.toIso8601String()}.
Строго используй эту дату как точку отсчета (сегодня) для высчитывания всех относительных дат 
(например: "завтра", "послезавтра", "в следующую пятницу", "через неделю", "утром").

Ты — помощник по автоматическому структурированию заметок. Твоя задача — принимать 
разрозненный или неструктурированный текст заметки и превращать его в аккуратную 
структуру. Пожалуйста, придумай короткий подходящий title. Улучши и очисти content 
(исправь опечатки и грамматику, но сохрани суть и подробности). 
$contactsContext
ПОДБОР ЦВЕТА И КАТЕГОРИИ:
ОБЯЗАТЕЛЬНО выбери осмысленный colorIndex и соответствующую ему КОРНЕВУЮ ПАПКУ для тега:
0 (желтый) -> "Идеи и заметки"
1 (красный) -> "Срочное и важное"
2 (зеленый) -> "Продукты и здоровье"
3 (синий) -> "Работа и учеба"
4 (фиолетовый) -> "Хобби и отдых"
5 (оранжевый) -> "Встречи и события"
6 (голубой) -> "Финансы и бизнес"
7 (розовый) -> "Личное и семья"
null (белый) -> "Разное"

ИНСТРУКЦИЯ ПО ТЕГАМ:
1. Каждая заметка должна иметь СТРОГО ОДИН тег.
2. Тег должен ОБЯЗАТЕЛЬНО начинаться с названия КОРНЕВОЙ ПАПКИ, соответствующей выбранному colorIndex.
3. Если нужно уточнить категорию, используй вложенность через "/": например, "Работа и учеба/Проект А/Дизайн".
4. Используй существующие подпапки из списка ниже, если они подходят.

СУЩЕСТВУЮЩИЕ ПАПКИ/ТЕГИ ПОЛЬЗОВАТЕЛЯ:
${existingFolders.isNotEmpty ? existingFolders.join(', ') : 'Список пуст'}

Строго возвращай ТОЛЬКО JSON объект (без markdown) следующей схемы:
{
  "title": "String",
  "content": "String",
  "tags": ["String"],
  "colorIndex": 4,
  "eventAt": "2024-05-20T18:00:00.000Z", // null if no event
  "reminderMinutes": 30, // null if no event
  "contacts": [
    {
      "name": "Имя",
      "phoneNumber": "+79991234567"
    }
  ]
}

Извлеки контакты (имена и телефоны). Твоя КРИТИЧЕСКАЯ задача — сопоставить упомянутых людей с справочником.
1. СНАЧАЛА проверь, есть ли упомянутое имя в СПРАВОЧНИКЕ КОНТАКТОВ ПОЛЬЗОВАТЕЛЯ. Если есть, ОБЯЗАТЕЛЬНО используй данные оттуда.
2. НЕ выдумывай новые контакты для обычных имен, если в тексте нет явного указания на создание контакта (например, "запиши номер", "новый контакт", "вот его телефон") или если рядом нет номера телефона.
3. Если номер телефона есть в тексте, привяжи его к контакту.
4. Если номера телефона НЕТ и человека нет в справочнике, НЕ добавляй его в список contacts, даже если это имя. Мы добавляем только реальные контакты для связи.

Проанализируй следующий текст заметки:
$rawContent
''';

      final text = await _generateWithRetry(prompt);
      if (text == null || text.isEmpty) {
        throw Exception('Gemini вернул пустой ответ.');
      }

      final jsonStr = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      dev.log('GeminiService: Raw AI JSON response: $jsonStr');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return StructuredNoteData.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Ошибка Gemini API: $e');
    }
  }

  Future<Map<String, StructuredNoteData>> structureNotesBatch(
    List<Note> notes, {
    List<NoteContact> userContacts = const [],
    List<String> existingFolders = const [],
  }) async {
    try {
      if (notes.isEmpty) return {};

      final now = DateTime.now();
      String contactsContext = '';
      if (userContacts.isNotEmpty) {
        final simplified = userContacts
            .map((c) => {'name': c.name, 'phone': c.phoneNumber})
            .toList();
        contactsContext =
            '\nСПРАВОЧНИК КОНТАКТОВ ПОЛЬЗОВАТЕЛЯ:\n${jsonEncode(simplified)}\n';
      }

      final notesList = notes.map((n) => {
        'id': n.id,
        'content': n.content,
      }).toList();

      final prompt = '''
Текущая дата и время системы: ${now.toIso8601String()}.
Строго используй эту дату как точку отсчета (сегодня) для высчитывания всех относительных дат 
(например: "завтра", "послезавтра", "в следующую пятницу", "через неделю", "утром").

Ты — помощник по автоматическому структурированию заметок. Твоя задача — обработать МАССИВ заметок.
Для каждой заметки из списка:
1. Придумай короткий подходящий title.
2. Улучши и очисти content (исправь опечатки и грамматику, но сохрани суть и подробности).
$contactsContext
ПОДБОР ЦВЕТА И КАТЕГОРИИ (для каждой заметки):
ОБЯЗАТЕЛЬНО выбери осмысленный colorIndex и соответствующую ему КОРНЕВУЮ ПАПКУ для тега:
0 (желтый) -> "Идеи и заметки"
1 (красный) -> "Срочное и важное"
2 (зеленый) -> "Продукты и здоровье"
3 (синий) -> "Работа и учеба"
4 (фиолетовый) -> "Хобби и отдых"
5 (оранжевый) -> "Встречи и события"
6 (голубой) -> "Финансы и бизнес"
7 (розовый) -> "Личное и семья"
null (белый) -> "Разное"

ИНСТРУКЦИЯ ПО ТЕГАМ:
1. Каждая заметка должна иметь СТРОГО ОДИН тег.
2. Тег должен ОБЯЗАТЕЛЬНО начинаться с названия КОРНЕВОЙ ПАПКИ, соответствующей выбранному colorIndex.
3. Если нужно уточнить категорию, используй вложенность через "/": например, "Работа и учеба/Проект А/Дизайн".
4. Используй существующие подпапки из списка ниже, если они подходят.

СУЩЕСТВУЮЩИЕ ПАПКИ/ТЕГИ ПОЛЬЗОВАТЕЛЯ:
${existingFolders.isNotEmpty ? existingFolders.join(', ') : 'Список пуст'}

ВХОДНЫЕ ЗАМЕТКИ ДЛЯ ОБРАБОТКИ (JSON):
${jsonEncode(notesList)}

Строго возвращай ТОЛЬКО JSON объект (без markdown), где ключи — это "id" заметки:
{
  "note_id_1": {
    "title": "String",
    "content": "String",
    "tags": ["String"],
    "colorIndex": 4,
    "eventAt": "ISO datetime or null",
    "reminderMinutes": 30 or null,
    "contacts": [{"name": "Имя", "phoneNumber": "Телефон"}]
  },
  ...
}
''';

      final text = await _generateWithRetry(prompt);
      if (text == null || text.isEmpty) throw Exception('Gemini вернул пустой ответ.');

      final jsonStr = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> resultsMap = jsonDecode(jsonStr);
      
      final Map<String, StructuredNoteData> finalResults = {};
      resultsMap.forEach((id, data) {
        finalResults[id] = StructuredNoteData.fromJson(data as Map<String, dynamic>);
      });
      
      return finalResults;
    } catch (e) {
      dev.log('GeminiService: Batch error: $e');
      throw Exception('Ошибка пакетной обработки Gemini: $e');
    }
  }
}
