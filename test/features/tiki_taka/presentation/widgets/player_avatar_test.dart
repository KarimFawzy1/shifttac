import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_avatar_image_provider.dart';
import 'package:shifttac/features/tiki_taka/domain/services/player_avatar_image_queue.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_avatar.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_diagonal_name.dart';

const _validCommonsUrl =
    'https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailingHttpClient();
}

class _FailingHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    throw const SocketException('Test network failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PlayerAvatarImageQueue.instance.resetForTest();
    PlayerAvatarDebugLog.resetForTest();
  });

  group('PlayerAvatar', () {
    testWidgets('null imageUrl shows person placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(const PlayerAvatar(imageUrl: null, size: 40)),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('empty imageUrl shows person placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(const PlayerAvatar(imageUrl: '   ', size: 40)),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('invalid host shows person placeholder without Image.network',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PlayerAvatar(
            imageUrl: 'https://www.transfermarkt.com/img/test.jpg',
            size: 40,
          ),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('malformed URL shows person placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(const PlayerAvatar(imageUrl: 'not-a-url', size: 40)),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('network failure shows person placeholder', (tester) async {
      HttpOverrides.global = _FailingHttpOverrides();
      addTearDown(() => HttpOverrides.global = null);

      await tester.pumpWidget(
        _wrap(const PlayerAvatar(imageUrl: _validCommonsUrl, size: 40)),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('network failure shows unavailableFallback when provided',
        (tester) async {
      HttpOverrides.global = _FailingHttpOverrides();
      addTearDown(() => HttpOverrides.global = null);

      await tester.pumpWidget(
        _wrap(
          const PlayerAvatar(
            imageUrl: _validCommonsUrl,
            size: 40,
            unavailableFallback: PlayerDiagonalName(displayName: 'Mohamed Salah'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Mohamed Salah'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
    });

    testWidgets('uses provided semantics label on placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PlayerAvatar(
            imageUrl: null,
            size: 40,
            semanticsLabel: 'Mohamed Salah',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Mohamed Salah'), findsOneWidget);
    });

    testWidgets('respects custom borderRadius', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PlayerAvatar(
            imageUrl: null,
            size: 48,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(8));
    });

    test('defaults to top-center alignment for face-first cover crop', () {
      const avatar = PlayerAvatar(imageUrl: 'https://example.com/x.jpg', size: 40);
      expect(avatar.fit, BoxFit.cover);
      expect(avatar.alignment, Alignment.topCenter);
    });

    test('playerAvatarImageProvider uses canonical decode size', () {
      final provider = playerAvatarImageProvider(_validCommonsUrl);
      final resize = provider as ResizeImage;
      expect(resize.width, kPlayerAvatarDecodeSize);
      expect(resize.height, kPlayerAvatarDecodeSize);
    });

    test('playerAvatarImageProvider is equal across display sizes', () {
      final searchProvider = playerAvatarImageProvider(_validCommonsUrl);
      final boardProvider = playerAvatarImageProvider(_validCommonsUrl);
      expect(identical(searchProvider, boardProvider), isTrue);
      expect(
        PaintingBinding.instance.imageCache.containsKey(searchProvider),
        PaintingBinding.instance.imageCache.containsKey(boardProvider),
      );
    });

    testWidgets('board avatar skips spinner when url already resolved',
        (tester) async {
      HttpOverrides.global = _FailingHttpOverrides();
      addTearDown(() => HttpOverrides.global = null);

      PlayerAvatarImageQueue.instance.markResolved(_validCommonsUrl);

      await tester.pumpWidget(
        _wrap(const PlayerAvatar(imageUrl: _validCommonsUrl, size: 100)),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
