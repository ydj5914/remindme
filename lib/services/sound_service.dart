import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _player = AudioPlayer();

  /// 오디오 파일 선택
  Future<File?> pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('파일 선택 실패: $e');
      return null;
    }
  }

  /// Firebase Storage에 업로드
  Future<String?> uploadSound(File file, String fileName) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final ref = _storage.ref().child('custom_sounds/$userId/$fileName');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      print('커스텀 소리 업로드 완료: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('업로드 실패: $e');
      return null;
    }
  }

  /// 소리 미리듣기
  Future<void> previewSound(String path) async {
    try {
      if (path.startsWith('http')) {
        await _player.play(UrlSource(path));
      } else {
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

  void dispose() {
    _player.dispose();
  }
}
