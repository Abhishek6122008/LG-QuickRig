import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/core/di/service_locator.dart';
import 'package:lg_quickrig/core/ssh/ssh_client.dart';
import 'package:lg_quickrig/core/ssh/ssh_credentials.dart';
import 'package:lg_quickrig/core/ssh/ssh_exception.dart';
import 'package:lg_quickrig/data/repositories/credentials_repository.dart';
import 'package:lg_quickrig/services/lg_command_service.dart';

/// Test doubles for the three seams every test needs. `Fake` (from
/// flutter_test) throws on anything not overridden, so a test that starts
/// touching new API fails loudly instead of silently getting null.
///
/// No mockito / build_runner on purpose — these classes are shorter than the
/// generated mocks would be, and they record commands in the form the
/// assertions actually check: the exact shell string sent to the rig.

/// Builds the real service graph, then swaps the only two seams that touch
/// the outside world: SSH and secure storage. Every screen resolves its
/// services through GetIt, so this is enough to drive the whole app offline —
/// used by the widget tests and the integration test alike.
Future<({FakeSSHClient ssh, FakeCredentialsRepository creds})>
    useFakeRig() async {
  await sl.reset();
  await setupServiceLocator();

  final ssh = FakeSSHClient();
  final creds = FakeCredentialsRepository();

  // The command/KML/orbit singletons are lazy, so replacing their dependency
  // before anything resolves them is enough — no other rewiring needed.
  await sl.unregister<LGSSHClient>();
  sl.registerSingleton<LGSSHClient>(ssh);
  await sl.unregister<CredentialsRepository>();
  sl.registerSingleton<CredentialsRepository>(creds);

  return (ssh: ssh, creds: creds);
}

/// Stands in for the real SSH transport. Records every command; replies with
/// [nextOutput], or whatever [outputFor] maps a matching command to.
class FakeSSHClient extends Fake implements LGSSHClient {
  final List<String> commands = [];
  final List<({List<int> bytes, String path})> uploads = [];

  /// Command substring -> canned stdout. First match wins.
  final Map<String, String> outputFor = {};
  String nextOutput = '';

  /// Commands whose substring appears here throw instead of returning —
  /// how a rebooting node behaves.
  final Set<String> failOn = {};

  final _stateCtrl = StreamController<SSHConnectionState>.broadcast();
  SSHConnectionState _state = SSHConnectionState.disconnected;
  SSHCredentials? _creds;

  /// Set to make [connect] fail the way a wrong password does.
  Object? connectError;

  @override
  Stream<SSHConnectionState> get stateStream => _stateCtrl.stream;

  @override
  SSHConnectionState get state => _state;

  @override
  bool get isConnected => _state == SSHConnectionState.connected;

  @override
  SSHCredentials? get credentials => _creds;

  void setState(SSHConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  @override
  Future<void> connect(
    SSHCredentials credentials, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    Duration connectTimeout = const Duration(seconds: 10),
  }) async {
    _creds = credentials;
    final err = connectError;
    if (err != null) {
      setState(SSHConnectionState.disconnected);
      throw err;
    }
    setState(SSHConnectionState.connected);
  }

  @override
  Future<void> disconnect() async => setState(SSHConnectionState.disconnected);

  @override
  Future<String> executeCommand(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    commands.add(command);
    for (final f in failOn) {
      if (command.contains(f)) throw LGSSHException('node went down: $f');
    }
    for (final entry in outputFor.entries) {
      if (command.contains(entry.key)) return entry.value;
    }
    return nextOutput;
  }

  @override
  Future<void> uploadBytes(List<int> bytes, String remotePath) async =>
      uploads.add((bytes: bytes, path: remotePath));

  @override
  Future<void> dispose() async => _stateCtrl.close();

  /// The single command containing [needle] — fails the test if there isn't
  /// exactly one, which is usually the real bug.
  String only(String needle) =>
      commands.singleWhere((c) => c.contains(needle));

  bool sent(String needle) => commands.any((c) => c.contains(needle));
}

/// For the KML and orbit controllers, which only ever see LGCommandService.
class FakeCommandService extends Fake implements LGCommandService {
  final List<String> commands = [];
  final List<({List<int> bytes, String path})> uploads = [];

  @override
  String host = '192.168.2.2';

  @override
  int nodeCount = 3;

  @override
  bool isConnected = true;

  String nextOutput = '';

  /// Set mid-test to make every later [execute] throw — a rig that went away
  /// while the app was still talking to it.
  Object? failWith;

  /// What readCameraTarget reports. Null = a fresh or already-consumed
  /// query.txt, which is the case the fallback logic exists for.
  ({double lat, double lng, double? range})? cameraTarget;

  @override
  Future<String> execute(String command) async {
    final err = failWith;
    if (err != null) throw err;
    commands.add(command);
    return nextOutput;
  }

  @override
  Future<void> uploadFile(List<int> bytes, String remotePath) async =>
      uploads.add((bytes: bytes, path: remotePath));

  @override
  Future<({double lat, double lng, double? range})?> readCameraTarget() async =>
      cameraTarget;

  /// Node-level actions. The real service builds multi-node SSH strings for
  /// these; recording the call instead lets the Copilot dispatch tests assert
  /// intent without re-testing the command builder.
  final List<String> actions = [];

  @override
  Future<void> reboot() async => actions.add('reboot');

  @override
  Future<void> shutdown() async => actions.add('shutdown');

  @override
  Future<void> relaunch() async => actions.add('relaunch');

  @override
  Future<void> sync() async => actions.add('sync');

  String only(String needle) =>
      commands.singleWhere((c) => c.contains(needle));

  bool sent(String needle) => commands.any((c) => c.contains(needle));
}

/// In-memory credentials — keeps flutter_secure_storage (and libsecret on
/// Linux CI) out of every test that isn't specifically about storage.
class FakeCredentialsRepository extends Fake implements CredentialsRepository {
  SSHCredentials? creds;
  String? geminiKey;
  bool copilotEnabled = false;

  CopilotUsage usage = CopilotUsage.empty();
  double dailyCapUsd = CredentialsRepository.defaultDailyCapUsd;

  int saveCount = 0;

  @override
  Future<SSHCredentials?> load() async => creds;

  @override
  Future<void> save(SSHCredentials c) async {
    creds = c;
    saveCount++;
  }

  @override
  Future<void> clear() async => creds = null;

  @override
  Future<String?> loadGeminiKey() async => geminiKey;

  @override
  Future<void> saveGeminiKey(String key) async => geminiKey = key;

  @override
  Future<void> deleteGeminiKey() async => geminiKey = null;

  @override
  Future<bool> loadCopilotEnabled() async => copilotEnabled;

  @override
  Future<void> saveCopilotEnabled(bool enabled) async =>
      copilotEnabled = enabled;

  @override
  Future<CopilotUsage> loadUsage() async => usage;

  @override
  Future<void> saveUsage(CopilotUsage u) async => usage = u;

  @override
  Future<double> loadDailyCapUsd() async => dailyCapUsd;

  @override
  Future<void> saveDailyCapUsd(double usd) async => dailyCapUsd = usd;
}
