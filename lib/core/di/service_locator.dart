import 'package:get_it/get_it.dart';

import '../../data/repositories/credentials_repository.dart';
import '../../services/lg_command_service.dart';
import '../../services/lg_kml_controller.dart';
import '../../services/lg_orbit_controller.dart';
import '../ssh/ssh_client.dart';

/// Global GetIt instance — import [sl] wherever you need to resolve a service.
final GetIt sl = GetIt.instance;

/// Registers every application-wide singleton in dependency order.
///
/// Called once in [main] before [runApp]. All registrations are lazy —
/// the object is created on first access, not at registration time.
///
/// Dependency graph (→ = "depends on"):
///   LGKMLController → LGCommandService → LGSSHClient
///   LGOrbitController → LGCommandService
class ServiceLocator {
  ServiceLocator._();

  static Future<void> setup() async {
    // Secure credential store — no dependencies.
    sl.registerLazySingleton<CredentialsRepository>(
      () => CredentialsRepository(),
    );

    // SSH transport — the single SSH connection for the whole app.
    sl.registerLazySingleton<LGSSHClient>(
      () => LGSSHClient(),
    );

    // Command service — thin wrapper over LGSSHClient that adds:
    //   • cluster-wide broadcasting (slave SSH loops)
    //   • system commands (reboot, shutdown, restart, sync)
    sl.registerLazySingleton<LGCommandService>(
      () => LGCommandService(sl<LGSSHClient>()),
    );

    // Domain controllers — each wraps LGCommandService with specific concerns.
    sl.registerLazySingleton<LGKMLController>(
      () => LGKMLController(sl<LGCommandService>()),
    );
    sl.registerLazySingleton<LGOrbitController>(
      () => LGOrbitController(sl<LGCommandService>()),
    );
  }
}
