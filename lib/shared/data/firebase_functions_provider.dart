import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import 'firebase_functions_client.dart';

final Provider<FirebaseFunctionsClient> firebaseFunctionsClientProvider =
    Provider<FirebaseFunctionsClient>((Ref ref) {
      return FirebaseFunctionsClient(auth: ref.watch(firebaseAuthProvider));
    });
