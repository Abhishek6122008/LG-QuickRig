import 'package:get_it/get_it.dart';

import '../../data/repositories/credentials_repository.dart';
import '../../services/lg_command_service.dart';
import '../../services/lg_kml_controller.dart';
import '../../services/lg_orbit_controller.dart';
import '../ssh/ssh_client.dart';

final GetIt sl = GetIt.instance;

class ServiceLocator {
  ServiceLocator._();

  static Future<void> setup() async {

    sl.registerLazySingleton<CredentialsRepository>(
      () => CredentialsRepository(),
    );

    sl.registerLazySingleton<LGSSHClient>(
      () => LGSSHClient(),
    );

    sl.registerLazySingleton<LGCommandService>(
      () => LGCommandService(sl<LGSSHClient>()),
    );

    sl.registerLazySingleton<LGKMLController>(
      () => LGKMLController(sl<LGCommandService>()),
    );
    sl.registerLazySingleton<LGOrbitController>(
      () => LGOrbitController(sl<LGCommandService>()),
    );
  }
}
