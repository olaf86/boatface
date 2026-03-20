import 'bootstrap.dart';
import 'firebase_options_stg.dart';

Future<void> main() async {
  await bootstrapBoatface(DefaultFirebaseOptions.currentPlatform);
}
