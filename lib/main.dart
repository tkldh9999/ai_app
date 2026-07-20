import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쓰레기 분류 앱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PlasticClassifierScreen(),
    );
  }
}

class PlasticClassifierScreen extends StatefulWidget {
  const PlasticClassifierScreen({super.key});

  @override
  State<PlasticClassifierScreen> createState() => _PlasticClassifierScreenState();
}

class _PlasticClassifierScreenState extends State<PlasticClassifierScreen> {
  XFile? _pickedFile;
  String _responseText = '사진을 선택하고 서버에 예측을 요청하세요.';
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedFile = image;
        _responseText = '사진이 선택되었습니다. 아래 [예측 결과 확인] 버튼을 누르세요.';
      });
    }
  }

  Future<void> _uploadAndPredict() async {
    if (_pickedFile == null) return;

    setState(() {
      _isLoading = true;
      _responseText = '서버에서 쓰레기 종류를 분석 중입니다...';
    });

    late Uri url = Uri.parse('http://ubtldhserver.kro.kr:8080/api/predict');

    try {
      var request = http.MultipartRequest('POST', url);

      if (kIsWeb) {
        // 파일 경로가 존재하지 않으므로 바이트 데이터를 읽어와 직접 첨부
        Uint8List imageBytes = await _pickedFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: _pickedFile!.name,
          ),
        );
      } else {
        request.files.add(
            await http.MultipartFile.fromPath('image', _pickedFile!.path)
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));

        if (responseData['status'] == 'success') {
          setState(() {
            _responseText = '🎉 분석 완료!\n\n예측 결과: ${responseData['label']}\n(클래스 인덱스: ${responseData['prediction']})';
          });
        } else {
          setState(() {
            _responseText = '서버 에러 발생: ${responseData['message']}';
          });
        }
      } else {
        setState(() {
          _responseText = '서버 응답 오류: 상태 코드 ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = '네트워크 연결 오류가 발생했습니다.\n서버 가동 여부 및 주소를 확인해 주세요.\n\n오류 내용: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('쓰레기 분류기'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: _pickedFile != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: kIsWeb
                    ? Image.network(_pickedFile!.path, fit: BoxFit.cover) // 웹용 렌더링
                    : Image.file(File(_pickedFile!.path), fit: BoxFit.cover), // 안드로이드용 렌더링
              )
                  : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('분석할 쓰레기 사진을 등록해 주세요.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _responseText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _isLoading
                ? const CircularProgressIndicator()
                : Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('사진 가져오기'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickedFile != null ? _uploadAndPredict : null,
                    icon: const Icon(Icons.analytics),
                    label: const Text('예측 결과 확인'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}