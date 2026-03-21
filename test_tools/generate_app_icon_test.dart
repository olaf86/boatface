import 'package:flutter_test/flutter_test.dart';

import '../tool/icon/app_icon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate boatface app icons', () async {
    await generateBoatfaceAppIcons();
  });
}
