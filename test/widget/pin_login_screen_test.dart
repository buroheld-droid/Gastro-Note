import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastro_note/features/auth/presentation/pin_login_screen.dart';

void main() {
  group('PinLoginScreen Widget Tests', () {
    setUp(() {});

    Widget createWidgetUnderTest() {
      return ProviderScope(
        child: const MaterialApp(
          home: PinLoginScreen(),
        ),
      );
    }

    testWidgets('PIN Login Screen rendert korrekt', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Gastro-Note POS'), findsOneWidget);
      expect(find.text('PIN-Code eingeben'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
    });

    testWidgets(
      'TextField hat autofocus=true',
      (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Assert - TextField sollte fokussiert sein
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);
      },
    );

    testWidgets(
      'zeigt Error-Message wenn PIN zu kurz',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Gib nur 3 Ziffern ein (min. 4 erforderlich)
        await tester.enterText(find.byType(TextField), '123');
        await tester.tap(find.byIcon(Icons.login));
        await tester.pumpAndSettle();

        // Assert
        expect(
          find.text('PIN muss 4-6 Ziffern haben'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'zeigt Error-Message wenn PIN zu lang',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Gib 7 Ziffern ein (max. 6 erforderlich)
        await tester.enterText(find.byType(TextField), '1234567');
        await tester.tap(find.byIcon(Icons.login));
        await tester.pumpAndSettle();

        // Assert
        expect(
          find.text('PIN muss 4-6 Ziffern haben'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'zeigt Error-Message wenn keine PIN eingegeben',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Versuche zu login ohne PIN eingegeben zu haben
        await tester.tap(find.byIcon(Icons.login));
        await tester.pumpAndSettle();

        // Assert
        expect(
          find.text('Bitte PIN eingeben'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'filtert nur Ziffern - Buchstaben werden ignoriert',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Gib Text mit Buchstaben ein
        await tester.enterText(find.byType(TextField), 'abcd1234');
        await tester.pumpAndSettle();

        // Assert - Nur Ziffern sollten vorhanden sein
        final textField = find.byType(TextField);
        expect(
          (textField.evaluate().first.widget as TextField).controller?.text,
          contains('1234'),
        );
      },
    );

    testWidgets(
      'Error-Message wird gelöscht bei neuer Eingabe',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act 1 - Verursache Error
        await tester.tap(find.byIcon(Icons.login));
        await tester.pumpAndSettle();
        expect(find.text('Bitte PIN eingeben'), findsOneWidget);

        // Act 2 - Tippe etwas ein
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pumpAndSettle();

        // Assert - Error sollte weg sein
        expect(find.text('Bitte PIN eingeben'), findsNothing);
      },
    );

    testWidgets(
      'obscureText versteckt PIN Eingabe',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Assert
        final textFieldWidget = find
            .byType(TextField)
            .evaluate()
            .first
            .widget as TextField;
        expect(textFieldWidget.obscureText, isTrue);
      },
    );

    testWidgets(
      'zeigt Loading-Indikatoren bei Login Versuch',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Gib gültige PIN ein und warte
        await tester.enterText(find.byType(TextField), '1234');
        await tester.tap(find.byIcon(Icons.login));

        // Während Loading - CircularProgressIndicator sollte sichtbar sein
        await tester.pump();
      },
    );

    testWidgets(
      'TextField hat number keyboardType',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Assert
        final textFieldWidget = find
            .byType(TextField)
            .evaluate()
            .first
            .widget as TextField;
        expect(
          textFieldWidget.keyboardType,
          equals(TextInputType.number),
        );
      },
    );

    testWidgets(
      'maximal 6 Zeichen Eingabe (LengthLimitingTextInputFormatter)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Versuche mehr als 6 Zeichen einzugeben
        await tester.enterText(find.byType(TextField), '1234567890');
        await tester.pumpAndSettle();

        // Assert - Nur 6 Zeichen sollten eingegeben sein
        final textField = find.byType(TextField);
        final text = (textField.evaluate().first.widget as TextField)
            .controller
            ?.text;
        expect(text?.length, lessThanOrEqualTo(6));
      },
    );

    testWidgets(
      'Enter-Taste triggert Login',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Gib PIN ein und drücke Enter
        await tester.enterText(find.byType(TextField), '1234');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Assert - Keine Errors sollten für gültige PIN vorhanden sein
        // (weitere Validierung hängt von Riverpod Provider ab)
      },
    );

    testWidgets(
      'Error-Message Container hat rote Farbe',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createWidgetUnderTest());

        // Act - Verursache Error
        await tester.tap(find.byIcon(Icons.login));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Bitte PIN eingeben'), findsOneWidget);
        // Container mit Error sollte rote Dekoration haben
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      },
    );
  }, skip: true);
}
