import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

class AudioConverter {
  /// WAV 文件头的大小（字节）
  static const int WAV_HEADER_SIZE = 44;

  /// 将 Opus 解码后的 PCM 数据转换为 WAV 文件
  /// [pcmData] PCM 格式的音频数据（已从 Opus 解码）
  /// [sampleRate] 采样率，默认为 16000
  /// [channels] 声道数，默认为 1（单声道）
  /// [bitsPerSample] 采样位数，默认为 16 bit
  /// 返回生成的 WAV 文件路径
  static Future<String> pcmToWav(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) async {
    try {
      // 验证 PCM 数据长度是否正确
      final bytesPerSample = bitsPerSample >> 3;
      final bytesPerFrame = channels * bytesPerSample;
      if (pcmData.length % bytesPerFrame != 0) {
        throw Exception(
          'Invalid PCM data length: ${pcmData.length} bytes is not divisible by $bytesPerFrame bytes per frame',
        );
      }

      // 对 PCM 数据进行规范化处理
      final normalizedPcmData = _normalizePcmData(pcmData, bitsPerSample);

      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final wavFile = File('${tempDir.path}/$timestamp.wav');

      // 创建 WAV 文件头
      final header = _createWavHeader(
        normalizedPcmData.length,
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: bitsPerSample,
      );

      // 写入 WAV 文件
      final wavData = Uint8List(WAV_HEADER_SIZE + normalizedPcmData.length);
      wavData.setAll(0, header);
      wavData.setAll(WAV_HEADER_SIZE, normalizedPcmData);

      await wavFile.writeAsBytes(wavData);

      return wavFile.path;
    } catch (e) {
      throw Exception('Failed to convert PCM to WAV: $e');
    }
  }

  /// 对 PCM 数据进行规范化处理
  static Uint8List _normalizePcmData(Uint8List pcmData, int bitsPerSample) {
    if (bitsPerSample != 16) return pcmData; // 目前只处理 16 位数据

    // 将字节数据转换为 Int16 数组
    final Int16List samples = Int16List.view(pcmData.buffer);

    // 找出最大振幅
    int maxAmplitude = 0;
    for (int i = 0; i < samples.length; i++) {
      maxAmplitude = math.max(maxAmplitude, samples[i].abs());
    }

    // 如果最大振幅太小，进行音量提升
    if (maxAmplitude < 16384) {
      // 32768 的一半
      final double gain = 16384 / maxAmplitude;
      for (int i = 0; i < samples.length; i++) {
        samples[i] = (samples[i] * gain).toInt().clamp(-32768, 32767);
      }
    }

    return Uint8List.view(samples.buffer);
  }

  /// 创建 WAV 文件头
  /// WAV 文件头格式参考：http://soundfile.sapp.org/doc/WaveFormat/
  static Uint8List _createWavHeader(
    int pcmDataLength, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final header = ByteData(WAV_HEADER_SIZE);
    final bytesPerSample = bitsPerSample >> 3;
    final blockAlign = channels * bytesPerSample;
    final byteRate = sampleRate * blockAlign;

    var offset = 0;

    // RIFF chunk descriptor
    header.setUint32(offset, 0x52494646, Endian.big); // "RIFF" in ASCII
    offset += 4;
    header.setUint32(
      offset,
      36 + pcmDataLength,
      Endian.little,
    ); // File size - 8
    offset += 4;
    header.setUint32(offset, 0x57415645, Endian.big); // "WAVE" in ASCII
    offset += 4;

    // "fmt " sub-chunk
    header.setUint32(offset, 0x666D7420, Endian.big); // "fmt " in ASCII
    offset += 4;
    header.setUint32(offset, 16, Endian.little); // Subchunk1Size (16 for PCM)
    offset += 4;
    header.setUint16(offset, 1, Endian.little); // AudioFormat (1 for PCM)
    offset += 2;
    header.setUint16(offset, channels, Endian.little); // NumChannels
    offset += 2;
    header.setUint32(offset, sampleRate, Endian.little); // SampleRate
    offset += 4;
    header.setUint32(offset, byteRate, Endian.little); // ByteRate
    offset += 4;
    header.setUint16(offset, blockAlign, Endian.little); // BlockAlign
    offset += 2;
    header.setUint16(offset, bitsPerSample, Endian.little); // BitsPerSample
    offset += 2;

    // "data" sub-chunk
    header.setUint32(offset, 0x64617461, Endian.big); // "data" in ASCII
    offset += 4;
    header.setUint32(offset, pcmDataLength, Endian.little); // Subchunk2Size

    return header.buffer.asUint8List();
  }

  /// 计算音频时长（秒）
  static double calculateDuration(
    int pcmDataLength,
    int sampleRate,
    int channels,
    int bitsPerSample,
  ) {
    final bytesPerSample = bitsPerSample >> 3;
    final bytesPerFrame = channels * bytesPerSample;
    final frames = pcmDataLength ~/ bytesPerFrame;
    return frames / sampleRate;
  }
}
