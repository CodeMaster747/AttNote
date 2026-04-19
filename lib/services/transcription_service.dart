// // services/transcription_service.dart
// // import 'dart:convert';
// import 'dart:io';
// import 'package:http/http.dart' as http;

// class TranscriptionService {
//   static const String _openAiApiUrl = 'https://api.openai.com/v1/audio/transcriptions';
//   static const String _apiKey = 'YOUR_OPENAI_API_KEY'; // Replace with your actual API key

//   Future<String?> transcribeAudio(File audioFile) async {
//     try {
//       var request = http.MultipartRequest('POST', Uri.parse(_openAiApiUrl));
      
//       request.headers.addAll({
//         'Authorization': 'Bearer $_apiKey',
//         'Content-Type': 'multipart/form-data',
//       });
      
//       request.fields['model'] = 'whisper-1';
//       request.fields['response_format'] = 'text';
      
//       request.files.add(
//         await http.MultipartFile.fromPath('file', audioFile.path),
//       );
      
//       final response = await request.send();
      
//       if (response.statusCode == 200) {
//         final responseData = await response.stream.bytesToString();
//         return responseData.trim();
//       } else {
//         print('Error transcribing audio: ${response.statusCode}');
//         return null;
//       }
//     } catch (e) {
//       print('Error in transcription service: $e');
//       return null;
//     }
//   }
// }
