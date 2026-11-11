import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/widgets/adhan_dialog.dart';
import 'adhan_playback_coordinator_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayerService mockAudioPlayer;
  late MockAppNotificationService mockNotificationService;
  late AdhanPlaybackCoordinatorImpl coordinator;

  setUp(() {
    mockAudioPlayer = MockAudioPlayerService();
    mockNotificationService = MockAppNotificationService();
    coordinator = AdhanPlaybackCoordinatorImpl(
      audioPlayer: mockAudioPlayer,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() async {
    await mockAudioPlayer.dispose();
  });

  Widget buildTestWidget({
    required Widget child,
    Locale locale = const Locale('ar'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  group('AdhanDialog UI & Behavioral Contract', () {
    testWidgets('1. Displays dialog with prayer name in Arabic and localized buttons',
        (tester) async {
      coordinator.markAdhanStarted('Asr');

      await tester.pumpWidget(
        buildTestWidget(
          child: AdhanDialog(
            prayerName: 'Asr',
            coordinator: coordinator,
          ),
        ),
      );
      await tester.pump();

      // Should show Arabic prayer name "العصر"
      expect(find.text('العصر'), findsOneWidget);
      // Should show Stop button "إيقاف الأذان"
      expect(find.text('إيقاف الأذان'), findsOneWidget);
      // Should show Close button "إغلاق"
      expect(find.text('إغلاق'), findsOneWidget);
    });

    testWidgets('2. Close button ONLY dismisses dialog: Adhan continues playing',
        (tester) async {
      coordinator.markAdhanStarted('Dhuhr');

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AdhanDialog(
                        prayerName: 'Dhuhr',
                        coordinator: coordinator,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.byType(AdhanDialog), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.byType(AdhanDialog), findsNothing);

      // CRITICAL CONTRACT: Adhan is STILL active and untouched!
      expect(coordinator.isAdhanActive, isTrue);
      expect(coordinator.activePrayerName, equals('Dhuhr'));
      expect(mockAudioPlayer.stopCallCount, equals(0));
    });

    testWidgets('3. Stop button invokes centralized stopCurrentAdhan and dismisses dialog',
        (tester) async {
      coordinator.markAdhanStarted('Maghrib');

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AdhanDialog(
                        prayerName: 'Maghrib',
                        coordinator: coordinator,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.byType(AdhanDialog), findsOneWidget);

      // Tap Stop button
      await tester.tap(find.text('إيقاف الأذان'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.byType(AdhanDialog), findsNothing);

      // Centralized stop was invoked and cleared active state
      expect(coordinator.isAdhanActive, isFalse);
      expect(coordinator.activePrayerName, isNull);
    });
  });
}
