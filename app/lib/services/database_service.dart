import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/subject.dart';
import '../models/schedule.dart';
import '../models/task_item.dart';
import '../models/absence.dart';
import '../models/grade.dart';
import 'notification_service.dart';

class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  DatabaseService();
  DatabaseService.withDatabase(this._database);

  static DatabaseService get instance {
    _instance ??= DatabaseService();
    return _instance!;
  }

  set database(Database? db) => _database = db;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'misemestre_utm.db');

    return await openDatabase(
      path,
      version: 3, // Migración a versión 3 para absences y grades
      onCreate: (db, version) async {
        await createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await createSchedulesTable(db);
          await createTasksTable(db);
        }
        if (oldVersion < 3) {
          await createAbsencesTable(db);
          await createGradesTable(db);
        }
      },
    );
  }

  static Future<void> createTables(DatabaseExecutor db) async {
    await createSubjectsTable(db);
    await createSchedulesTable(db);
    await createTasksTable(db);
    await createAbsencesTable(db);
    await createGradesTable(db);
    await createSyncMetaTable(db);
  }

  static Future<void> createSubjectsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        teacher TEXT,
        color TEXT,
        max_absences INTEGER,
        passing_grade REAL NOT NULL DEFAULT 8.0,
        grade_scale REAL NOT NULL DEFAULT 10.0,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  static Future<void> createSchedulesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  static Future<void> createTasksTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'task',
        title TEXT NOT NULL,
        description TEXT,
        due_at TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        photo_url TEXT,
        local_photo_path TEXT,
        reminders TEXT NOT NULL DEFAULT '[1440,120]',
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  static Future<void> createAbsencesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS absences (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        date TEXT NOT NULL,
        justified INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  static Future<void> createGradesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS grades (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        score REAL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }

  static Future<void> createSyncMetaTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ==========================================
  // --- MATERIAS (SUBJECTS) ---
  // ==========================================

  Future<List<Subject>> getSubjects() async {
    final db = await database;
    final maps = await db.query(
      'subjects',
      where: 'deleted_at IS NULL AND sync_status != ?',
      whereArgs: ['pending_delete'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Subject.fromDbMap(m)).toList();
  }

  Future<Subject?> getSubjectById(String id) async {
    final db = await database;
    final maps = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Subject.fromDbMap(maps.first);
  }

  Future<void> insertSubject(Subject subject) async {
    final db = await database;
    await db.insert(
      'subjects',
      subject.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSubject(Subject subject) async {
    final db = await database;
    await db.update(
      'subjects',
      subject.toDbMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> markSubjectDeleted(String id) async {
    final db = await database;
    final current = await getSubjectById(id);
    if (current == null) return;

    final now = DateTime.now().toUtc().toIso8601String();

    // Cancelar recordatorios de todas las tareas pertenecientes a esta materia
    final subjectTasks = await db.query('tasks', where: 'subject_id = ?', whereArgs: [id]);
    for (final t in subjectTasks) {
      final taskId = t['id'] as String?;
      if (taskId != null) {
        await NotificationService.instance.cancelTaskReminders(taskId);
      }
    }

    if (current.syncStatus == 'pending_create') {
      await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
      await db.delete('schedules', where: 'subject_id = ?', whereArgs: [id]);
      await db.delete('tasks', where: 'subject_id = ?', whereArgs: [id]);
      await db.delete('absences', where: 'subject_id = ?', whereArgs: [id]);
      await db.delete('grades', where: 'subject_id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'subjects',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.update(
        'schedules',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'subject_id = ?',
        whereArgs: [id],
      );
      await db.update(
        'tasks',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'subject_id = ?',
        whereArgs: [id],
      );
      await db.update(
        'absences',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'subject_id = ?',
        whereArgs: [id],
      );
      await db.update(
        'grades',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'subject_id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteSubject(String id) async {
    final db = await database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Subject>> getPendingSubjects() async {
    final db = await database;
    final maps = await db.query(
      'subjects',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return maps.map((m) => Subject.fromDbMap(m)).toList();
  }

  Future<void> upsertSubjectFromSync(Subject subject) async {
    final db = await database;

    final existing = await getSubjectById(subject.id);
    if (existing != null && existing.syncStatus != 'synced') {
      return;
    }

    if (subject.deletedAt != null) {
      await markSubjectDeleted(subject.id);
      await db.delete('subjects', where: 'id = ?', whereArgs: [subject.id]);
    } else {
      await db.insert(
        'subjects',
        subject.copyWith(syncStatus: 'synced').toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ==========================================
  // --- HORARIO (SCHEDULES) ---
  // ==========================================

  Future<List<Schedule>> getSchedules({int? dayOfWeek, String? subjectId}) async {
    final db = await database;
    final whereClauses = [
      's.deleted_at IS NULL',
      's.sync_status != ?',
      'sub.deleted_at IS NULL',
      'sub.sync_status != ?',
    ];
    final whereArgs = <dynamic>['pending_delete', 'pending_delete'];

    if (dayOfWeek != null) {
      whereClauses.add('s.day_of_week = ?');
      whereArgs.add(dayOfWeek);
    }
    if (subjectId != null) {
      whereClauses.add('s.subject_id = ?');
      whereArgs.add(subjectId);
    }

    final query = '''
      SELECT s.* FROM schedules s
      INNER JOIN subjects sub ON s.subject_id = sub.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY s.day_of_week ASC, s.start_time ASC
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) => Schedule.fromDbMap(m)).toList();
  }

  Future<Schedule?> getScheduleById(String id) async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Schedule.fromDbMap(maps.first);
  }

  Future<void> insertSchedule(Schedule schedule) async {
    final db = await database;
    await db.insert(
      'schedules',
      schedule.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSchedule(Schedule schedule) async {
    final db = await database;
    await db.update(
      'schedules',
      schedule.toDbMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> markScheduleDeleted(String id) async {
    final db = await database;
    final current = await getScheduleById(id);
    if (current == null) return;

    if (current.syncStatus == 'pending_create') {
      await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'schedules',
        {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'sync_status': 'pending_delete',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteSchedule(String id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Schedule>> getPendingSchedules() async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return maps.map((m) => Schedule.fromDbMap(m)).toList();
  }

  Future<void> upsertScheduleFromSync(Schedule schedule) async {
    final db = await database;

    final existing = await getScheduleById(schedule.id);
    if (existing != null && existing.syncStatus != 'synced') {
      return;
    }

    if (schedule.deletedAt != null) {
      await db.delete('schedules', where: 'id = ?', whereArgs: [schedule.id]);
    } else {
      await db.insert(
        'schedules',
        schedule.copyWith(syncStatus: 'synced').toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ==========================================
  // --- TAREAS Y EXÁMENES (TASKS) ---
  // ==========================================

  Future<List<TaskItem>> getTasks({String? subjectId, bool? done}) async {
    final db = await database;
    final whereClauses = [
      't.deleted_at IS NULL',
      't.sync_status != ?',
      'sub.deleted_at IS NULL',
      'sub.sync_status != ?',
    ];
    final whereArgs = <dynamic>['pending_delete', 'pending_delete'];

    if (subjectId != null) {
      whereClauses.add('t.subject_id = ?');
      whereArgs.add(subjectId);
    }
    if (done != null) {
      whereClauses.add('t.done = ?');
      whereArgs.add(done ? 1 : 0);
    }

    final query = '''
      SELECT t.* FROM tasks t
      INNER JOIN subjects sub ON t.subject_id = sub.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY t.due_at ASC
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) => TaskItem.fromDbMap(m)).toList();
  }

  Future<TaskItem?> getTaskById(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskItem.fromDbMap(maps.first);
  }

  Future<void> insertTask(TaskItem task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(TaskItem task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toDbMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> markTaskDeleted(String id) async {
    final db = await database;
    final current = await getTaskById(id);
    if (current == null) return;

    await NotificationService.instance.cancelTaskReminders(id);

    if (current.syncStatus == 'pending_create') {
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'tasks',
        {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'sync_status': 'pending_delete',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteTask(String id) async {
    final db = await database;
    await NotificationService.instance.cancelTaskReminders(id);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskItem>> getPendingTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return maps.map((m) => TaskItem.fromDbMap(m)).toList();
  }

  Future<List<TaskItem>> getTasksWithPendingPhotoUpload() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'deleted_at IS NULL AND local_photo_path IS NOT NULL AND (photo_url IS NULL OR photo_url = ?)',
      whereArgs: [''],
    );
    return maps.map((m) => TaskItem.fromDbMap(m)).toList();
  }

  Future<void> upsertTaskFromSync(TaskItem task) async {
    final db = await database;

    final existing = await getTaskById(task.id);
    if (existing != null && existing.syncStatus != 'synced') {
      return;
    }

    if (task.deletedAt != null) {
      // Cancelar recordatorios huérfanos si la tarea fue borrada en el servidor
      await NotificationService.instance.cancelTaskReminders(task.id);
      await db.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
    } else {
      // Si el servidor trae photoUrl, ya no necesitamos localPhotoPath
      final localPhoto = task.photoUrl != null ? null : existing?.localPhotoPath;
      await db.insert(
        'tasks',
        task.copyWith(syncStatus: 'synced', localPhotoPath: localPhoto).toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ==========================================
  // --- FALTAS (ABSENCES) ---
  // ==========================================

  Future<List<Absence>> getAbsences({String? subjectId}) async {
    final db = await database;
    final whereClauses = [
      'a.deleted_at IS NULL',
      'a.sync_status != ?',
      'sub.deleted_at IS NULL',
      'sub.sync_status != ?',
    ];
    final whereArgs = <dynamic>['pending_delete', 'pending_delete'];

    if (subjectId != null) {
      whereClauses.add('a.subject_id = ?');
      whereArgs.add(subjectId);
    }

    final query = '''
      SELECT a.* FROM absences a
      INNER JOIN subjects sub ON a.subject_id = sub.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY a.date DESC
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) => Absence.fromDbMap(m)).toList();
  }

  Future<Absence?> getAbsenceById(String id) async {
    final db = await database;
    final maps = await db.query(
      'absences',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Absence.fromDbMap(maps.first);
  }

  Future<void> insertAbsence(Absence absence) async {
    final db = await database;
    await db.insert(
      'absences',
      absence.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAbsence(Absence absence) async {
    final db = await database;
    await db.update(
      'absences',
      absence.toDbMap(),
      where: 'id = ?',
      whereArgs: [absence.id],
    );
  }

  Future<void> markAbsenceDeleted(String id) async {
    final db = await database;
    final current = await getAbsenceById(id);
    if (current == null) return;

    if (current.syncStatus == 'pending_create') {
      await db.delete('absences', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'absences',
        {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'sync_status': 'pending_delete',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteAbsence(String id) async {
    final db = await database;
    await db.delete('absences', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Absence>> getPendingAbsences() async {
    final db = await database;
    final maps = await db.query(
      'absences',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return maps.map((m) => Absence.fromDbMap(m)).toList();
  }

  Future<void> upsertAbsenceFromSync(Absence absence) async {
    final db = await database;

    final existing = await getAbsenceById(absence.id);
    if (existing != null && existing.syncStatus != 'synced') {
      return;
    }

    if (absence.deletedAt != null) {
      await db.delete('absences', where: 'id = ?', whereArgs: [absence.id]);
    } else {
      await db.insert(
        'absences',
        absence.copyWith(syncStatus: 'synced').toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ==========================================
  // --- CALIFICACIONES (GRADES) ---
  // ==========================================

  Future<List<Grade>> getGrades({String? subjectId}) async {
    final db = await database;
    final whereClauses = [
      'g.deleted_at IS NULL',
      'g.sync_status != ?',
      'sub.deleted_at IS NULL',
      'sub.sync_status != ?',
    ];
    final whereArgs = <dynamic>['pending_delete', 'pending_delete'];

    if (subjectId != null) {
      whereClauses.add('g.subject_id = ?');
      whereArgs.add(subjectId);
    }

    final query = '''
      SELECT g.* FROM grades g
      INNER JOIN subjects sub ON g.subject_id = sub.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY g.created_at ASC
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) => Grade.fromDbMap(m)).toList();
  }

  Future<Grade?> getGradeById(String id) async {
    final db = await database;
    final maps = await db.query(
      'grades',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Grade.fromDbMap(maps.first);
  }

  Future<void> insertGrade(Grade grade) async {
    final db = await database;
    await db.insert(
      'grades',
      grade.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGrade(Grade grade) async {
    final db = await database;
    await db.update(
      'grades',
      grade.toDbMap(),
      where: 'id = ?',
      whereArgs: [grade.id],
    );
  }

  Future<void> markGradeDeleted(String id) async {
    final db = await database;
    final current = await getGradeById(id);
    if (current == null) return;

    if (current.syncStatus == 'pending_create') {
      await db.delete('grades', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'grades',
        {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'sync_status': 'pending_delete',
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteGrade(String id) async {
    final db = await database;
    await db.delete('grades', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Grade>> getPendingGrades() async {
    final db = await database;
    final maps = await db.query(
      'grades',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return maps.map((m) => Grade.fromDbMap(m)).toList();
  }

  Future<void> upsertGradeFromSync(Grade grade) async {
    final db = await database;

    final existing = await getGradeById(grade.id);
    if (existing != null && existing.syncStatus != 'synced') {
      return;
    }

    if (grade.deletedAt != null) {
      await db.delete('grades', where: 'id = ?', whereArgs: [grade.id]);
    } else {
      await db.insert(
        'grades',
        grade.copyWith(syncStatus: 'synced').toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ==========================================
  // --- VERIFICACIÓN DE CAMBIOS PENDIENTES ---
  // ==========================================

  Future<bool> hasPendingChanges() async {
    final pendingSub = await getPendingSubjects();
    if (pendingSub.isNotEmpty) return true;

    final pendingSch = await getPendingSchedules();
    if (pendingSch.isNotEmpty) return true;

    final pendingTsk = await getPendingTasks();
    if (pendingTsk.isNotEmpty) return true;

    final pendingAbs = await getPendingAbsences();
    if (pendingAbs.isNotEmpty) return true;

    final pendingGrd = await getPendingGrades();
    return pendingGrd.isNotEmpty;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('grades');
    await db.delete('absences');
    await db.delete('tasks');
    await db.delete('schedules');
    await db.delete('subjects');
    await db.delete('sync_meta');
  }
}
