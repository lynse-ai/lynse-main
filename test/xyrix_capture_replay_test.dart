/// 真机抓包重放测试：2026-09-24 19:50 会话原始字节，按不同 BLE 通知分包
/// 边界重放，直接驱动生产代码 `XyrixNotificationRouter`。
///
/// 对应联调问题：「设备回了列表但 app 不显示」（0x05 与结束 ACK 同通知时
/// 帧解码抢先消费 ACK 导致列表静默丢失）与「实时 OPUS 需要本地落盘」。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dting/hardware/models.dart';
import 'package:dting/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:dting/hardware/xyrix/xyrix_stream_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 0x05 起始帧 + 1083B 明文列表 + 结束 ACK（真机 19:50 会话 offset 76..1169）
const String _listSegmentB64 =
    '/1WqAAUwOi8yMDI2LTA5LTIxLTA5LTU3LTM0LndhdiAtMTQ1OTc2IEIgLTM2ODAgcwowOi8yMDI2LTA5LTE4LTEzLTUxLTM1LndhdiAtNjk5Mjc3OTUgQiAtMTgzMDA2NCBzCjA6LzIwMjYtMDktMDgtMDktMjYtNDgud2F2IC0xMzEyMTM5NiBCIC0zODA2NzAgcwowOi8yMDI2LTA4LTE4LTIwLTI2LTAzLndhdiAtMTQxNDQ3IEIgLTM1NzUgcwowOi8yMDI2LTA5LTA4LTAxLTI2LTQwLndhdiAtOTgyNzU1MzAgQiAtMjg4MDA0OCBzCjA6LzIwMjYtMDgtMTgtMjAtMDUtNDAud2F2IC0xNDY3NjUgQiAtMzM3NCBzCjA6LzIwMjYtMDktMDctMTctMjYtMzUud2F2IC05NzMwNzc1NSBCIC0yODgwMDg0IHMKMDovMjAyNi0wOS0wNy0xNi0wMS0zNC53YXYgLTIxNTQ2Mjk4IEIgLTUwODIwMCBzCjA6LzIwMjYtMDktMDQtMTQtMDEtMjgud2F2IC01MTQzMDM2IEIgLTE0NDE1MCBzCjA6LzIwMjYtMDktMDQtMTQtMDEtMDMud2F2IC01OTg2MCBCIC0xNDQ0IHMKMDovMjAyNi0wOS0wNC0xMC0yNC01NS53YXYgLTYwMTYzNDUgQiAtMTYwMzMyIHMKMDovMjAyNi0wOS0wMy0xMC0xOS0xMS53YXYgLTExNDkzOSBCIC0yNjk4IHMKMDovMjAyNi0wOS0wMy0xMC0xOC0zOS53YXYgLTQyOTc1IEIgLTEwMzAgcwowOi8yMDI2LTA5LTAyLTAyLTMzLTE3LndhdiAtMjQ2Njk4MjkgQiAtNzQ4OTUwIHMKMDovMjAyNi0wOC0xMi0xMS0xOS0zMS53YXYgLTEwMjUzNSBCIC0yMzU2IHMKMDovMjAyNi0wOC0xMi0xMS0xOC0yOC53YXYgLTE0NDE3MSBCIC0zNDM0IHMKMDovMjAyNi0wOS0wMS0xOC0zMy0xNS53YXYgLTk4MTI2NDE2IEIgLTI4ODAwMjggcwowOi8yMDI2LTA5LTAxLTA5LTMzLTE3LndhdiAtOTg2NTk0MTcgQiAtMjYzMDY5MCBzCjA6LzIwMjYtMDktMDEtMDQtNTYtMzkud2F2IC0yNTgwNjY0MyBCIC03MDAxMDAgcwowOi8yMDI2LTA4LTMxLTIwLTU2LTM3LndhdiAtMTAwOTA2ODg5IEIgLTI4ODAwMDggcwowOi8yMDI2LTA4LTMxLTIwLTUxLTU0LndhdiAtMjE0MDYwIEIgLTUwMzIgcwowOi8yMDI2LTA4LTExLTA5LTQ4LTA5LndhdiAtNDE1MTcgQiAtOTYyIHMKMDovMjAyNi0wOC0zMS0yMC0zMi0wNS53YXYgLTUxMjY1IEIgLTEzMDggcwr/VaoALw==';

/// 首个 0x54 标记帧起的实时流前 2500B（真机 19:50 会话 offset 4448..）
const String _rtSegmentB64 =
    '/1WqAFQAagAAAAAIAAAAAAAAAEgL5MEiI2HwBwAAAAAAAABIB8l184BYBwAAAAAAAABIB8l5wSRYBwAAAAAAAABIB8l9jshYBwAAAAAAAABIB8lyJduKBwAAAAAAAABIB8l184BYBwAAAAAAAABIB8l5wSRYBLj/VaoAVAEsAAAAAQcAAAAAAAAASAfJfY7IWAcAAAAAAAAASAfJciXbigcAAAAAAAAASAfJdfOAWAcAAAAAAAAASAfJecEkWAcAAAAAAAAASAfJfY7IWC8AAAAAAAAASJjo2WgjrHt4WjDLWtZzr6jf0QVpAs+q4cw/lhzgOjdKElE7bzBL6bomziC5fcAlAAAAAAAAAEigYYq30Ap6isU8ixc+NC6bNEGiXNTSMpBOgQmj4Q1mYJVftOAPAAAAAAAAAEifxPcqS3qLt99AELYLOBYAAAAAAAAASJ0wdJjc4lVtD8QOlA2/ufOGmIKT6A8AAAAAAAAASJwIAF+MaQPi1xAGjhk0GgAAAAAAAABImxeXb8MLalrZxuOBvo+jp/jZvrTJcRdNzBAAAAAAAAAASJqLYihvzAvK/1WqAFQBLAAAAAIo4ODI7XyRFIwbAAAAAAAAAEgvXZ4fQQ7b888HE7MDMDeUxIqgeyPdBRijaBoAAAAAAAAASC0eTEz6xF4lqiGDEENWt/g5kHrWegwjiYAUAAAAAAAAAEgpcCoEhGG8mFX1dklQGxk41ZbAGgAAAAAAAABIJxNvKGoy5ckXgUaRKi0OiaNCgXVttL5AgBkAAAAAAAAASCEDspe+u+pHZIyXEjIpQDaelQfKWkitsBoAAAAAAAAASBsqqtiNL9GwhEcq0V+96zEVleGkd0pouqIYAAAAAAAAAEgXgORAoDoKARxZ6CpPI/pzkB38/J9dNRgAAAAAAAAASBG7qtitmE0BxsmW3QDMGuzewcN3VP8wOwAAAAAAAABImKRv5U3KieC/4Iuy3O/yhFpFOBryL/9VqgBUASwAAAAD9H7wIyj6vO7r0UofUp7O2GuSKp9Ajv1EgCezXMxwD/0UvD9a1IQnAAAAAAAAAEihz2KYhSFBwA8LwhVzJdtwdrsqouIZY7sa6pa9z3YHBu4x+ltYiCMAAAAAAAAASIKOMpjFeskqG6IdxMt01f4ndZZTnI231WcWYCQOQo4fOgRXAAAAAAAAAEiO1IaqDBTW6KXJVOEgQ0YL6xPnIpQWx0UA/Nsxn9/IkybOVB5jUvQAo4vSVYxQGUwPT77XZeIdQNJ1xNF+Ji2HwYCttQOr0w3Ou59wOrNaz21REMjfNlQAAAAAAAAASI81ZxTYlWf14FqsTGAMNjwsqi/BXpx8mrLLLfV9HEPOz8xBXBOqn8lORCHhhg07baK2SGYh9P40TWRhOcWZ11NwFkrjBEj/VaoAVAEoAAAABPP9QQIy9PSf78pknGs56VIAAAAAAAAASI81ZyQrMi8Ujo5gTDKQz9kbmb9hqatxWbk0VgRLgTETK4Jz6Jh4Nw4qGBKDEMQV+Hmw41tKVyiGgD/wd1w/kxoN+MFBsotVvec0e5tgehKMaFUAAAAAAAAASI80NbC0o9fOqm1UbZmM2DdzBsb0Ga9LdF+Mo9PKJ4rX1dmjaSoQVaHCvLFjhBkINUCFefAaFgodSGtYGTnnspATA9533zvjWDyDluYVrmAnbrmkr1oAAAAAAAAASKfPCPZSd3XTWonPN9oMN/hWbvHTJqVhf670HhAw22xqfVryBMuQD3hhOlk1mp7CaymyY3tkR0JCt8s6gp9xdQWtXiscmKqgokHb5j8Tjz5JSrYw8Zb3Szro3OP/VaoAVABgAAAABVgAAAAAAAAASKfOUSQ5hMZNA4bIuOA4Cd1Hox7yRPz8YHQViVNa18gwTqbOi+t9cD9jGq1iPY86FiO+fpdIMmZ9CujVAOxxIqftOJnmGMlGSMqEExHS7q4Uk37xmlRmVtAR/1WqAFQAXgAAAAZWAAAAAAAAAEinzwj23FX5VaaNd3h/Zc19YG9bN2oarP9zfiZlBHjH9fQ3zBy2A0JiCyvw/EApLPbT7Wh6bvYFEeM/l2Aprg5Ms1ssEbFva8RhQJT245HGSC31DrxsuaP/VaoAVABrAAAAB2MAAAAAAAAASKfPCHNAYodcmhAVE/488FHoYC0Xux/0ENJFd/jFkXfWkjRncagXZmgJmpA3icDG4zKZ5gTtMJS6ijFqydH0Ty2xQ/HV72hmwO8nI39ke8j1JAm839Ev+qP+NG7wN2J5y/DwFRr/VaoAVABkAAAACFwAAAAAAAAASKe+QutSJ+X/PYzh6JVTPvQqblPkeoaD8zXAJ+omb2gn5JZUk6mBj1nCfer68DR+HF7xFeBxAwYQj24NnZqktcNKinIK9xhb1eolFmhh44S8EsDc0voA+TNOZ1c7If9VqgBUAGYAAAAJXgAAAAAAAABIp75C0xSqGFCzIxuQrmZcErmuESBB5Ssxg80THYCoA5tD2hAjguWLXewUKmXaIm0KGxZIVnShMh+p0/lKIIb3wkkSPXUK9/PWv/ADqYp7dMpUqcxsISTh979xIBjAO0n/VaoAVABjAAAAClsAAAAAAAAASKfOUuYavqlvx5hg3oXyUxoVDeJTYva/Z/WG27ucnrdiZ1ljp11GoPmJUoHPD5KJGIYolfv36NlFaGCpxcZhEh9AXoQL/eowVxVbbhoYuc7I0UHF57F3C+XoWSu4/1WqAFQAawAAAAtjAAAAAAAAAEin+GVnf+hJkg9HJaRMPrpeXBFQLJ9oJxiPKTHlSPJ7UxecMRs0FKAGrC30/nxWr9DITaSqy+dlu9ruSfoomVXtyzOqZ1/Al0r83VYpnuZoLQhoeLlvrLKN2EbKvS78IZjGLEJT/1WqAFQAaAAAAAxgAAAAAAAAAEipgRLr7FxFdW186irAFagmczDB5xi7icSQM7FV7/8e4nP92WeJ36CcXmIN9h22x7muNC8jjazCmxPc2QCmWkbjJPwsCrpcjk1d47Esz0vSrQLLLNPsNvmveDMK3IItkBEr/1WqAFQAZAAAAA1cAAAAAAAAAEipcQLvDF/5MM7zWOVzktFRDdrE6hzvnCje/O1mGpdGfDmE3JXy2lRHld5dDIkhILfJysodyocY5GxTvuzF9ky8yT1MX/Yzl1qt42SUu5zfvL29dxBYcwHDblcsP3L/VaoAVABcAAAADlQAAAAAAAAASKmBD/at8ymZ8y8gDNjWCK+Zin+RX1EaCelEmm5FavGHYXQ3gQUSUHAR7Y61+M5BlbU8mtCV1z/dwN1GoD8eeFhwkC0qb57rlAWoyplZEm0akG+4Ov7/VQ==';

Uint8List _seg(String b64) => Uint8List.fromList(base64Decode(b64));

void main() {
  group('文件列表管线重放（真机抓包 19:50 会话）', () {
    for (final chunkSize in [5, 16, 32, 64, 128, 181, 240, 512, 1093, 4096]) {
      test('通知分包 $chunkSize B → 解析出全部 23 个文件', () {
        final seg = _seg(_listSegmentB64);
        final lists = <List<RecordingFile>>[];
        final router = XyrixNotificationRouter(
          onFrame: (_) {},
          onFileList: lists.add,
          onOpusPacket: (_) {},
        );
        var i = 0;
        while (i < seg.length) {
          final end = (i + chunkSize).clamp(0, seg.length);
          router.feed(Uint8List.sublistView(seg, i, end));
          i = end;
        }
        expect(lists, isNotEmpty, reason: '分包 $chunkSize 时应完成解析');
        final files = lists.last;
        expect(files.length, 23);
        expect(files.first.name, '2026-09-21-09-57-34.wav');
        expect(files.first.sizeBytes, 145976);
        expect(files.first.startTime, DateTime(2026, 9, 21, 9, 57, 34));
        expect(files[1].name, '2026-09-18-13-51-35.wav');
        expect(files[1].sizeBytes, 69927795);
      });
    }
  });

  group('实时音频流管线重放（真机抓包 0x54 段）', () {
    for (final chunkSize in [5, 8, 16, 32, 64, 115, 240, 512, 2500]) {
      test('通知分包 $chunkSize B → 15 包 / 2303B 载荷 / 序列号连续', () {
        final seg = _seg(_rtSegmentB64);
        final packets = <XyrixOpusPacket>[];
        final router = XyrixNotificationRouter(
          onFrame: (_) {},
          onFileList: (_) {},
          onOpusPacket: packets.add,
        );
        var i = 0;
        while (i < seg.length) {
          final end = (i + chunkSize).clamp(0, seg.length);
          router.feed(Uint8List.sublistView(seg, i, end));
          i = end;
        }
        expect(packets.length, 15, reason: '分包 $chunkSize 时应解出全部数据包');
        expect(packets.map((p) => p.payload.length).reduce((a, b) => a + b), 2303);
        expect([for (var k = 0; k < 15; k++) packets[k].seq], 
            [for (var k = 0; k < 15; k++) k]);
      });
    }
  });
}
