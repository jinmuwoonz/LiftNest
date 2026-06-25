import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/exercise.dart';
import '../models/exercise_inventory.dart';
import '../models/exercise_workout.dart';
import '../models/inventory.dart';
import '../models/weight.dart';
import '../models/workout.dart';

/// Singleton helper that owns the sqflite [Database] instance and all
/// CRUD operations for LiftNest.
class DatabaseHelper {
  static const String _databaseName = 'liftnest.db';
  static const int _databaseVersion = 3;

  // ── Table names ──────────────────────────────────────────────────────────
  static const String tableWorkout = 'Workout';
  static const String tableExercise = 'Exercise';
  static const String tableExerciseWorkout = 'ExerciseWorkout';
  static const String tableInventory = 'Inventory';
  static const String tableExerciseInventory = 'ExerciseInventory';
  static const String tableWeight = 'Weight';

  // ── Singleton plumbing ───────────────────────────────────────────────────
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ── Initialisation ───────────────────────────────────────────────────────
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableExercise ADD COLUMN pool_inventories INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableExerciseWorkout ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// Enable foreign-key enforcement (disabled by default in SQLite).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableWorkout (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        description TEXT,
        day         TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableExercise (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        name                TEXT    NOT NULL,
        description         TEXT,
        target_weight_kg    REAL,
        target_weight_lb    REAL,
        sets               INTEGER,
        repetition          INTEGER,
        rest_time           INTEGER,
        is_dual_bar         INTEGER NOT NULL DEFAULT 1,
        include_bar_weight  INTEGER NOT NULL DEFAULT 0,
        pool_inventories    INTEGER NOT NULL DEFAULT 1,
        bar_weight_kg       REAL,
        bar_weight_lb       REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableExerciseWorkout (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        workout_id  INTEGER NOT NULL,
        sort_order  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (exercise_id) REFERENCES $tableExercise (id)
          ON DELETE CASCADE,
        FOREIGN KEY (workout_id)  REFERENCES $tableWorkout  (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableInventory (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableExerciseInventory (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id  INTEGER NOT NULL,
        inventory_id INTEGER NOT NULL,
        FOREIGN KEY (exercise_id)  REFERENCES $tableExercise  (id)
          ON DELETE CASCADE,
        FOREIGN KEY (inventory_id) REFERENCES $tableInventory (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWeight (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_id INTEGER NOT NULL,
        weight_kg    REAL    NOT NULL,
        weight_lb    REAL    NOT NULL,
        quantity     INTEGER NOT NULL DEFAULT 1,
        description  TEXT,
        FOREIGN KEY (inventory_id) REFERENCES $tableInventory (id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WORKOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return db.insert(tableWorkout, workout.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final maps = await db.query(tableWorkout);
    return maps.map(Workout.fromMap).toList();
  }

  Future<Workout?> getWorkoutById(int id) async {
    final db = await database;
    final maps =
        await db.query(tableWorkout, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await database;
    return db.update(tableWorkout, workout.toMap(),
        where: 'id = ?', whereArgs: [workout.id]);
  }

  Future<int> deleteWorkout(int id) async {
    final db = await database;
    return db.delete(tableWorkout, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXERCISE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return db.insert(tableExercise, exercise.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final maps = await db.query(tableExercise);
    return maps.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> getExerciseById(int id) async {
    final db = await database;
    final maps =
        await db.query(tableExercise, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Exercise.fromMap(maps.first);
  }

  /// Returns all exercises linked to a given [workoutId], sorted by sort_order.
  Future<List<Exercise>> getExercisesForWorkout(int workoutId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT e.* FROM $tableExercise e
      INNER JOIN $tableExerciseWorkout ew ON e.id = ew.exercise_id
      WHERE ew.workout_id = ?
      ORDER BY ew.sort_order ASC
    ''', [workoutId]);
    return maps.map(Exercise.fromMap).toList();
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    return db.update(tableExercise, exercise.toMap(),
        where: 'id = ?', whereArgs: [exercise.id]);
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return db.delete(tableExercise, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXERCISE ↔ WORKOUT  (junction)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertExerciseWorkout(ExerciseWorkout ew) async {
    final db = await database;
    // Auto-assign sort_order = current count so new items go to the end.
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableExerciseWorkout WHERE workout_id = ?',
      [ew.workoutId],
    );
    final nextOrder = (countResult.first['cnt'] as int? ?? 0);
    return db.insert(
      tableExerciseWorkout,
      ew.copyWith(sortOrder: nextOrder).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> deleteExerciseWorkout(int exerciseId, int workoutId) async {
    final db = await database;
    return db.delete(tableExerciseWorkout,
        where: 'exercise_id = ? AND workout_id = ?',
        whereArgs: [exerciseId, workoutId]);
  }

  /// Updates the sort_order for each exercise in [orderedExerciseIds] within [workoutId].
  Future<void> updateExerciseOrder(
      int workoutId, List<int> orderedExerciseIds) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < orderedExerciseIds.length; i++) {
      batch.update(
        tableExerciseWorkout,
        {'sort_order': i},
        where: 'workout_id = ? AND exercise_id = ?',
        whereArgs: [workoutId, orderedExerciseIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVENTORY
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertInventory(Inventory inventory) async {
    final db = await database;
    return db.insert(tableInventory, inventory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Inventory>> getAllInventories() async {
    final db = await database;
    final maps = await db.query(tableInventory);
    return maps.map(Inventory.fromMap).toList();
  }

  Future<Inventory?> getInventoryById(int id) async {
    final db = await database;
    final maps =
        await db.query(tableInventory, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Inventory.fromMap(maps.first);
  }

  Future<int> updateInventory(Inventory inventory) async {
    final db = await database;
    return db.update(tableInventory, inventory.toMap(),
        where: 'id = ?', whereArgs: [inventory.id]);
  }

  Future<int> deleteInventory(int id) async {
    final db = await database;
    return db.delete(tableInventory, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXERCISE ↔ INVENTORY  (junction)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertExerciseInventory(ExerciseInventory ei) async {
    final db = await database;
    return db.insert(tableExerciseInventory, ei.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteExerciseInventory(
      int exerciseId, int inventoryId) async {
    final db = await database;
    return db.delete(tableExerciseInventory,
        where: 'exercise_id = ? AND inventory_id = ?',
        whereArgs: [exerciseId, inventoryId]);
  }

  /// Returns the inventory linked to an exercise (assumes one per exercise).
  Future<Inventory?> getInventoryForExercise(int exerciseId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.* FROM $tableInventory i
      INNER JOIN $tableExerciseInventory ei ON i.id = ei.inventory_id
      WHERE ei.exercise_id = ?
      LIMIT 1
    ''', [exerciseId]);
    if (maps.isEmpty) return null;
    return Inventory.fromMap(maps.first);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> insertWeight(Weight weight) async {
    final db = await database;
    return db.insert(tableWeight, weight.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns all weights for a given [inventoryId], sorted heaviest first.
  Future<List<Weight>> getWeightsForInventory(int inventoryId) async {
    final db = await database;
    final maps = await db.query(
      tableWeight,
      where: 'inventory_id = ?',
      whereArgs: [inventoryId],
      orderBy: 'weight_kg DESC',
    );
    return maps.map(Weight.fromMap).toList();
  }

  Future<int> updateWeight(Weight weight) async {
    final db = await database;
    return db.update(tableWeight, weight.toMap(),
        where: 'id = ?', whereArgs: [weight.id]);
  }

  Future<int> deleteWeight(int id) async {
    final db = await database;
    return db.delete(tableWeight, where: 'id = ?', whereArgs: [id]);
  }

  /// Returns the number of distinct weight entries in a given [inventoryId].
  Future<int> getWeightCountForInventory(int inventoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableWeight WHERE inventory_id = ?',
      [inventoryId],
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  // ── Inventory ↔ Exercise ─────────────────────────────────────────────────

  /// Returns all inventories linked to [exerciseId], in insertion order.
  Future<List<Inventory>> getInventoriesForExercise(int exerciseId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT i.* FROM $tableInventory i
      INNER JOIN $tableExerciseInventory ei ON i.id = ei.inventory_id
      WHERE ei.exercise_id = ?
      ORDER BY ei.id ASC
    ''', [exerciseId]);
    return maps.map(Inventory.fromMap).toList();
  }

  /// Deletes all ExerciseInventory rows for [exerciseId].
  Future<int> deleteExerciseInventoryByExercise(int exerciseId) async {
    final db = await database;
    return db.delete(
      tableExerciseInventory,
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
    );
  }

  // ── Exercise count per workout ────────────────────────────────────────────

  /// Returns the number of exercises linked to [workoutId].
  Future<int> getExerciseCountForWorkout(int workoutId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableExerciseWorkout WHERE workout_id = ?',
      [workoutId],
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  /// Returns the number of workouts that contain [exerciseId].
  Future<int> getWorkoutCountForExercise(int exerciseId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableExerciseWorkout WHERE exercise_id = ?',
      [exerciseId],
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  /// Closes the database connection. Call only when the app is terminating.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
