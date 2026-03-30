import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;

import '../../data/models/structured_note_data.dart';
import '../services/settings_service.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref);
});

class GeminiService {
  final Ref _ref;
  late final GenerativeModel _primaryModel;
  final String _modelName = 'gemini-2.5-flash';

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
      final response = await _primaryModel.generateContent([Content.text(prompt)]);
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
        generationConfig: google_ai.GenerationConfig(responseMimeType: 'application/json'),
      );
      
      final response = await fallbackModel.generateContent([google_ai.Content.text(prompt)]);
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

  Future<StructuredNoteData?> structureNote(String rawContent) async {
    try {
      if (rawContent.trim().isEmpty) return null;

      final now = DateTime.now();
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
Подбери случайный colorIndex от 0 до 15. 
Если в тексте идет речь о будущем событии, встрече, задаче с конкретным ИЛИ примерным временем 
(например, "завтра утром", "в обед", "в понедельник"), вычисли точное время события на основе 
текущей даты и верни его как eventAt в формате ISO-8601. 
Если время (часы/минуты) не указано, выбери логичное время по умолчанию (например, 09:00 для утра).
Если это событие, обязательно добавь напоминание: установи reminderMinutes (например, 15, 30, 60).

Строго возвращай ТОЛЬКО JSON объект (без markdown) следующей схемы:
{
  "title": "String",
  "content": "String",
  "tags": ["String"],
  "colorIndex": 4,
  "eventAt": "2024-05-20T18:00:00.000Z", // null if no event
  "reminderMinutes": 30 // null if no event
}

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
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return StructuredNoteData.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Ошибка Gemini API: $e');
    }
  }
}
