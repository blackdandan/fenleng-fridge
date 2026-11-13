import 'package:fridge/application/bootstrap.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class MemoryStorage implements InventoryStorage {
  InventoryState? state;
  MemoryStorage(this.state);
  @override
  Future<InventoryState?> load() async => state;
  @override
  Future<void> save(InventoryState next) async {
    state = next;
  }
}

class ReadyBootstrap extends FridgeBootstrap {
  @override
  bool get onlineConsent => stage == BootstrapStage.ready;
  @override
  Future<void> ensureOnlineServices() async {}
  ReadyBootstrap(InventoryRepository repository, FridgeStrings resources) {
    inventory = repository;
    strings = resources;
    stage = BootstrapStage.ready;
  }
  @override
  Future<void> initialize() async {}
}
