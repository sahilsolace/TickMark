import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickmark/models/daily_summary_model.dart';
import 'package:tickmark/theme/app_theme.dart';
import 'package:tickmark/widgets/daily_summary_cards.dart';
import 'package:tickmark/widgets/date_navigation_bar.dart';
import 'package:tickmark/widgets/mini_tracker_widget.dart';

void main() {
  testWidgets('DailySummaryCards displays summary values correctly', (WidgetTester tester) async {
    final summary = DailySummaryModel(
      workDate: '2026-11-23',
      totalSeconds: 7200,
      billableSeconds: 5400,
      nonBillableSeconds: 1800,
      totalTasks: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DailySummaryCards(summary: summary),
        ),
      ),
    );

    expect(find.text('Total Hours'), findsOneWidget);
    expect(find.text('Billable Hours'), findsOneWidget);
    expect(find.text('Non-Billable'), findsOneWidget);
    expect(find.text('Total Tasks'), findsOneWidget);
    expect(find.text('02:00:00'), findsOneWidget);
    expect(find.text('01:30:00'), findsOneWidget);
    expect(find.text('00:30:00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('DateNavigationBar displays date and controls', (WidgetTester tester) async {
    final now = DateTime.now();
    final testDate = DateTime(now.year, now.month, now.day);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DateNavigationBar(
            selectedDate: testDate,
            canGoPrevious: true,
            canGoNext: false,
            isToday: true,
            isYesterday: false,
            onPreviousDay: () {},
            onNextDay: () {},
            onToday: () {},
            onSelectDate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('MiniTrackerWidget displays header and controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MiniTrackerWidget(
          onExpandToFull: () {},
        ),
      ),
    );

    expect(find.text('TickMark'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full_rounded), findsWidgets);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
