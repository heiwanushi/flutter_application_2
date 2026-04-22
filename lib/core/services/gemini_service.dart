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
Извлеки массив тегов tags. ВАЖНО: Если заметка короткая (1-2 предложения), верни максимум 1 тег. 
Если заметка длинная, верни максимум 3 тега. 
Подбери осмысленный colorIndex. Доступные варианты:
null - белый (нейтральный, по умолчанию)
0 - желтый (идеи, заметки)
1 - красный (срочное, важное)
2 - зеленый (продукты, покупки, здоровье)
3 - синий (учеба, работа)
4 - фиолетовый (хобби, отдых)
5 - оранжевый (встречи, события)
6 - голубой (финансы, бизнес)
7 - розовый (личное, семья)
Если в тексте идет речь о будущем событии, встрече, задаче с конкретным ИЛИ примерным временем 
(например, "завтра утром", "в обед", "в понедельник"), вычисли точное время события на основе 
текущей даты и верни его как eventAt в формате ISO-8601. 
Если время (часы/минуты) не указано, выбери логичное время по умолчанию (например, 09:00 для утра).
Если это событие, обязательно добавь напоминание: установи reminderMinutes (например, 15, 30, 60).

$contactsContext

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
3. Извлеки массив тегов tags. ВАЖНО: Если заметка короткая (1-2 предложения), верни максимум 1 тег. 
   Если заметка длинная, верни максимум 3 тега. 
4. Подбери осмысленный colorIndex. Доступные варианты:
   null - белый (нейтральный, по умолчанию)
   0 - желтый (идеи, заметки)
   1 - красный (срочное, важное)
   2 - зеленый (продукты, покупки, здоровье)
   3 - синий (учеба, работа)
   4 - фиолетовый (хобби, отдых)
   5 - оранжевый (встречи, события)
   6 - голубой (финансы, бизнес)
   7 - розовый (личное, семья)
5. Если в тексте идет речь о будущем событии, встрече, задаче с конкретным ИЛИ примерным временем 
   (например, "завтра утром", "в обед", "в понедельник"), вычисли точное время события на основе 
   текущей даты и верни его как eventAt в формате ISO-8601. 
   Если время (часы/минуты) не указано, выбери логичное время по умолчанию (например, 09:00 для утра).
6. Если это событие, обязательно добавь напоминание: установи reminderMinutes (например, 15, 30, 60).

Извлеки контакты (имена и телефоны). Твоя КРИТИЧЕСКАЯ задача — сопоставить упомянутых людей с справочником.
1. СНАЧАЛА проверь, есть ли упомянутое имя в СПРАВОЧНИКЕ КОНТАКТОВ ПОЛЬЗОВАТЕЛЯ. Если есть, ОБЯЗАТЕЛЬНО используй данные оттуда.
2. НЕ выдумывай новые контакты для обычных имен, если в тексте нет явного указания на создание контакта (например, "запиши номер", "новый контакт", "вот его телефон") или если рядом нет номера телефона.
3. Если номер телефона есть в тексте, привяжи его к контакту.
4. Если номера телефона НЕТ и человека нет в справочнике, НЕ добавляй его в список contacts, даже если это имя. Мы добавляем только реальные контакты для связи.

$contactsContext

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
