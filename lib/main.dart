import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 임포트
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
  // 💡 중요: dart:io의 File 대신 크로스플랫폼을 지원하는 XFile 객체를 사용합니다.
  XFile? _pickedFile;
  String _responseText = '사진을 선택하고 서버에 예측을 요청하세요.';
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // 1. 갤러리에서 이미지 가져오기 (웹/안드로이드 공용)
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedFile = image;
        _responseText = '사진이 선택되었습니다. 아래 [예측 결과 확인] 버튼을 누르세요.';
      });
    }
  }

  // 2. 웹 & 안드로이드 통합형 서버 전송 로직
  Future<void> _uploadAndPredict() async {
    if (_pickedFile == null) return;

    setState(() {
      _isLoading = true;
      _responseText = '서버에서 플라스틱 종류를 분석 중입니다...';
    });

    // 💡 환경별 엔드포인트 주소 분기 처리
    late Uri url = Uri.parse('http://ubtldhserver.kro.kr:8080/api/predict');

    try {
      var request = http.MultipartRequest('POST', url);

      // 💡 [핵심] 플랫폼에 따른 파일 전송 방식 다변화
      if (kIsWeb) {
        // 웹: 파일 경로가 존재하지 않으므로 바이트 데이터를 읽어와 직접 첨부
        Uint8List imageBytes = await _pickedFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: _pickedFile!.name,
          ),
        );
      } else {
        // 안드로이드: 로컬 스토리지에 저장된 실제 경로(Path)를 이용해 첨부
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
        title: const Text('쓰레기 재질 분류기'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // [상단] 플랫폼 호환 이미지 렌더링 영역
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
                    ? Image.network(_pickedFile!.path, fit: BoxFit.cover) // 웹용 렌더링 방식 (Blob URL 가리킴)
                    : Image.file(File(_pickedFile!.path), fit: BoxFit.cover), // 안드로이드용 렌더링 방식
              )
                  : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('분석할 플라스틱 사진을 등록해 주세요.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // [중간] 결과 메시지 출력 영역
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

            // [하단] 버튼 컨트롤 영역
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