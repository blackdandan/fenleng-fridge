part of 'bootstrap.dart';

mixin _InventoryActions {
  InventoryRepository? get inventory;
  Directory? get dataDirectory;
  void recordEvent(String name, Map<String, String> properties);

  Future<void> organize(FoodRecord food, Remaining remaining) async {
    await inventory!.update(
      (state) =>
          InventoryRules.organize(state, {food.id: remaining}, DateTime.now()),
    );
    recordEvent('fridge.review.updated.v1', {
      'state': remaining.name,
      'zone': (inventory!.state.foods[food.id] ?? food).zone.name,
    });
  }

  Future<void> restore(FoodRecord food) => inventory!.update(
    (state) => InventoryRules.restore(state, food.id, DateTime.now()),
  );

  Future<void> editRecord(
    FoodRecord food, {
    required StorageZone zone,
    required int intervalDays,
    required DateTime addedAt,
    DateTime? dueAt,
  }) => inventory!.update(
    (state) => InventoryRules.edit(
      state,
      food.id,
      zone: zone,
      intervalDays: intervalDays,
      addedAt: addedAt,
      dueAt: dueAt,
    ),
  );

  PhotoLifecycle _photoLifecycle() => PhotoLifecycle(
    repository: inventory!,
    photos: ManagedFoodPhotos(directory: dataDirectory!),
    snapshotReferences: FileInventoryStorage(dataDirectory!).photoReferences,
  );

  Future<void> replacePhoto(FoodRecord food) =>
      _photoLifecycle().replace(food.id);

  Future<void> deleteRecord(FoodRecord food) async {
    await inventory!.update(
      (state) => InventoryRules.delete(state, food.id),
      undoable: false,
      invalidateUndo: true,
    );
    try {
      await ManagedFoodPhotos(
        directory: dataDirectory!,
      ).discardSaved(food.photoPath);
    } catch (_) {
      /* A failed private-file cleanup cannot resurrect a deleted record. */
    }
  }
}
