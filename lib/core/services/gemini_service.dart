import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../../data/models/structured_note_data.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<StructuredNoteData?> structureNote(String rawContent) async {
    try {
      if (rawContent.trim().isEmpty) return null;

      final now = DateTime.now();
      final prompt = '''
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

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      
      if (text == null || text.isEmpty) {
        throw Exception('Gemini вернул пустой ответ.');
      }

      final jsonStr = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return StructuredNoteData.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Ошибка Gemini API: $e');
    }
  }
}
