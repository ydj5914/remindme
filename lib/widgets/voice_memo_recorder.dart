import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/voice_memo_service.dart';

class VoiceMemoRecorder extends StatefulWidget {
  final Function(String? path) onRecordingComplete;

  const VoiceMemoRecorder({super.key, required this.onRecordingComplete});

  @override
  State<VoiceMemoRecorder> createState() => _VoiceMemoRecorderState();
}

class _VoiceMemoRecorderState extends State<VoiceMemoRecorder> {
  final VoiceMemoService _voiceService = VoiceMemoService();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;
  String? _uploadedUrl;

  @override
  void dispose() {
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 녹음 중지
      final path = await _voiceService.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });

      // Firebase Storage에 업로드
      if (path != null) {
        final url = await _voiceService.uploadToStorage(path);
        setState(() {
          _uploadedUrl = url;
        });
        widget.onRecordingComplete(url);
      }
    } else {
      // 녹음 시작
      await _voiceService.startRecording();
      setState(() {
        _isRecording = true;
        _recordedPath = null;
        _uploadedUrl = null;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _voiceService.stop();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_uploadedUrl != null || _recordedPath != null) {
        await _voiceService.play(_uploadedUrl ?? _recordedPath!);
        setState(() {
          _isPlaying = true;
        });

        // 재생 완료 후 상태 업데이트
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Voice Memo', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),

            // 녹음 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _toggleRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.fiber_manual_record,
                  ),
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: _isRecording
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),

                // 재생 버튼
                if (_recordedPath != null || _uploadedUrl != null)
                  IconButton.filled(
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                    ),
                  ),

                // 삭제 버튼
                if (_recordedPath != null || _uploadedUrl != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _recordedPath = null;
                        _uploadedUrl = null;
                      });
                      widget.onRecordingComplete(null);
                    },
                    icon: const Icon(Icons.delete),
                  ),
              ],
            ),

            // 상태 표시
            const SizedBox(height: 8),
            if (_isRecording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            if (_uploadedUrl != null)
              Text(
                '✓ Saved',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            if (_recordedPath != null && _uploadedUrl == null)
              Text(
                'Uploading...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
