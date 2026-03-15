import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          responseMimeType: 'application/json',
        ),
      );

      final imageBytes = await File(imagePath).readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final prompt = TextPart('''
        Peran: Kamu adalah mesin penghitung kalori otomatis.
        Tugas: Estimasi total kalori dari makanan di gambar ini.

        DO:
        1. Fokus UTAMA hanya pada estimasi angka kalori (kkal).
        2. Jika nama makanan sulit dikenali, cukup beri nama umum (contoh: "Makanan", "Snack", "Menu Siang").
        3. Berikan output HANYA dalam format JSON yang valid.

        DONT:
        1. JANGAN memberikan penjelasan, intro, atau penutup.
        2. JANGAN menggunakan format markdown (seperti ```json).
        3. JANGAN menebak terlalu spesifik jika gambar tidak jelas, ambil rata-rata kalori visualnya saja.
        4. JANGAN biarkan field JSON kosong.

        Format JSON Wajib:
        {
          "is_food" : boolean, (true jika makana, false jika bukan)
          "food_name": "Nama Umum Makanan",
          "calories": 0
        }
        ''');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      String cleanText = response.text ?? "";
      cleanText = cleanText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return cleanText;
    } catch (e) {
      print("Error Gemini Image: $e");
      return null;
    }
  }
  Future<String?> analyzeFood(String imagePath) async {

  static const String _apiKey = '';

  Future<String?> chatWithNutritionist(String userMessage) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: '',
      );

      final prompt =
      '''
      Peran: Kamu adalah "Nutribot", asisten ahli gizi pribadi yang ramah, pintar, dan suportif.
      Tugas: Jawab pertanyaan pengguna seputar nutrisi, diet, kesehatan, dan kalori makanan.
      
      Gaya Bicara:
      - Gunakan Bahasa Indonesia yang santai tapi sopan.
      - Berikan jawaban yang ringkas, padat, dan mudah dimengerti.
      - Jika pengguna bertanya di luar topik kesehatan/makanan, tolak dengan halus.
      - Gunakan emoji sesekali agar tidak kaku.

      Pertanyaan User: "$userMessage"
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      print("Error Gemini Chat: $e");
      return "Maaf, saya sedang pusing. Coba tanya lagi nanti ya! 😵‍💫";
    }
  }

  Future<int?> calculateCaloriesFromText(String foodName, String description) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: '',
        generationConfig: GenerationConfig(
          temperature: 0.4,
          responseMimeType: 'application/json',
        ),
      );

      final prompt = '''
      Peran: Kamu adalah kalkulator kalori makanan yang sangat presisi.
      
      Tugas: Hitung total kalori berdasarkan data berikut:
      1. Nama Makanan: "$foodName"
      2. Detail/Komposisi: "$description"
      
      Instruksi:
      - Gunakan "Detail/Komposisi" untuk membuat estimasi seakurat mungkin.
      - Jika detail kosong, gunakan rata-rata umum untuk makanan tersebut.
      - Output WAJIB JSON.
      
      Format JSON:
      {
        "calories": 0 (integer)
      }
      ''';

      final response = await model.generateContent([Content.text(prompt)]);

      String cleanText = response.text ?? "";
      cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '').trim();
      final RegExp regExp = RegExp(r'"calories":\s*(\d+)');
      final match = regExp.firstMatch(cleanText);

      if (match != null) {
        return int.parse(match.group(1)!);
      } else {
        return 0;
      }
    } catch (e) {
      print("Error Gemini Text Calc: $e");
      return null;
    }
  }
}