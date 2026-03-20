import 'bootstrap.dart';
import 'firebase_options_prod.dart';

Future<void> main() async {
  await bootstrapBoatface(DefaultFirebaseOptions.currentPlatform);
}
