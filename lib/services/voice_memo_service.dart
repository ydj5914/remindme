import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoiceMemoService {
  static final VoiceMemoService _instance = VoiceMemoService._internal();
  factory VoiceMemoService() => _instance;
  VoiceMemoService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentRecordingPath;

  /// 녹음 시작
  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        _currentRecordingPath = path;
        print('녹음 시작: $path');
      }
    } catch (e) {
      print('녹음 시작 실패: $e');
      rethrow;
    }
  }

  /// 녹음 중지 및 저장
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      print('녹음 완료: $path');
      return path;
    } catch (e) {
      print('녹음 중지 실패: $e');
      return null;
    }
  }

  /// Firebase Storage에 업로드
  Future<String?> uploadToStorage(String localPath) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final file = File(localPath);
      if (!await file.exists()) return null;

      final fileName =
          'voice_memos/$userId/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage.ref().child(fileName);

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      print('업로드 완료: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('업로드 실패: $e');
      return null;
    }
  }

  /// 음성 메모 재생
  Future<void> play(String path) async {
    try {
      if (path.startsWith('http')) {
        // URL
        await _player.play(UrlSource(path));
      } else {
        // 로컬 파일
        await _player.play(DeviceFileSource(path));
      }
    } catch (e) {
      print('재생 실패: $e');
    }
  }

  /// 재생 중지
  Future<void> stop() async {
    await _player.stop();
  }

  /// 녹음 중인지 확인
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
