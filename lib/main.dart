import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 패키지 임포트

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTTP 통신 앱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HttpTestScreen(),
    );
  }
}

class HttpTestScreen extends StatefulWidget {
  const HttpTestScreen({super.key});

  @override
  State<HttpTestScreen> createState() => _HttpTestScreenState();
}

class _HttpTestScreenState extends State<HttpTestScreen> {
  String _responseText = '아래 버튼을 눌러 서버에 요청을 보내세요.';
  bool _isLoading = false;

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('https://jsonplaceholder.typicode.com/posts/1');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _responseText = '데이터 수신 성공!\n\n${response.body}';
        });
      } else {
        setState(() {
          _responseText = '서버 에러 발생: 상태 코드 ${response.statusCode}';
        });
      }
    } catch (e) {
      // 인터넷 연결 끊김, 주소 오류 등의 예외 처리
      setState(() {
        _responseText = '네트워크 에러가 발생했습니다:\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false; // 로딩 종료
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP 통신 테스트'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 결과를 보여주는 텍스트 창
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _responseText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 로딩 중이면 빙글빙글 도는 애니메이션, 아니면 버튼 표시
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _fetchData,
                child: const Text('서버에 데이터 요청하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}