import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';
import '../models/schedule.dart';
import '../models/task_item.dart';
import '../models/absence.dart';
import '../models/grade.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiService {
  static ApiService? _instance;
  http.Client client;

  /// Callback global para cuando el servidor responda 401 (token inválido o expirado)
  void Function()? onUnauthorized;

  ApiService({http.Client? client}) : client = client ?? http.Client();

  static ApiService get instance {
    _instance ??= ApiService();
    return _instance!;
  }

  String get _baseUrl => ApiConfig.instance.baseUrl;

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await StorageService.instance.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String errorMsg = 'Error en el servidor (${response.statusCode})';
    dynamic details;
    if (body is Map<String, dynamic>) {
      if (body['error'] != null) {
        errorMsg = body['error'].toString();
      }
      details = body['details'];
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMsg,
      details: details,
    );
  }

  /// Método privado centralizado para TODAS las peticiones HTTP.
  /// Aplica timeout de 10 segundos y convierte SocketException, ClientException
  /// y TimeoutException en ApiException(statusCode: 0, message: 'Sin conexión con el servidor').
  Future<dynamic> _send(
    String method,
    String path, {
    dynamic body,
    bool requireAuth = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final url = Uri.parse('$_baseUrl$path');
      final headers = await _getHeaders(requireAuth: requireAuth);

      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(url, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await client
              .post(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await client
              .patch(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await client.delete(url, headers: headers).timeout(timeout);
          break;
        default:
          throw ApiException(
            statusCode: 400,
            message: 'Método HTTP no soportado: $method',
          );
      }

      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Sin conexión con el servidor',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Sin conexión con el servidor',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Sin conexión con el servidor',
      );
    }
  }

  // --- HEALTH CHECK ---

  Future<bool> checkHealth() async {
    try {
      final res = await _send(
        'GET',
        '/api/health',
        requireAuth: false,
        timeout: const Duration(seconds: 4),
      );
      return res is Map && res['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // --- AUTH ---

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      requireAuth: false,
    ) as Map<String, dynamic>;

    return {
      'token': data['token'] as String,
      'user': User.fromJson(data['user'] as Map<String, dynamic>),
    };
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      requireAuth: false,
    ) as Map<String, dynamic>;

    return {
      'token': data['token'] as String,
      'user': User.fromJson(data['user'] as Map<String, dynamic>),
    };
  }

  Future<User> getMe() async {
    final data = await _send('GET', '/api/me') as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<void> deleteMe() async {
    await _send('DELETE', '/api/me');
  }

  // --- MATERIAS ---

  Future<List<Subject>> getSubjects() async {
    final list = await _send('GET', '/api/subjects') as List<dynamic>;
    return list.map((item) => Subject.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Subject> getSubject(String id) async {
    final data = await _send('GET', '/api/subjects/$id') as Map<String, dynamic>;
    return Subject.fromJson(data);
  }

  Future<Subject> createSubject(Subject subject) async {
    final data = await _send(
      'POST',
      '/api/subjects',
      body: subject.toJson(includeId: true),
    ) as Map<String, dynamic>;
    return Subject.fromJson(data);
  }

  Future<Subject> updateSubject(String id, Map<String, dynamic> changes) async {
    final data = await _send(
      'PATCH',
      '/api/subjects/$id',
      body: changes,
    ) as Map<String, dynamic>;
    return Subject.fromJson(data);
  }

  Future<void> deleteSubject(String id) async {
    await _send('DELETE', '/api/subjects/$id');
  }

  Future<SubjectSummary> getSubjectSummary(String id) async {
    final data = await _send('GET', '/api/subjects/$id/summary') as Map<String, dynamic>;
    return SubjectSummary.fromJson(data);
  }

  // --- HORARIOS (SCHEDULES) ---

  Future<List<Schedule>> getSchedules({String? subjectId}) async {
    var path = '/api/schedules';
    if (subjectId != null) path += '?subjectId=${Uri.encodeComponent(subjectId)}';
    final list = await _send('GET', path) as List<dynamic>;
    return list.map((item) => Schedule.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Schedule> createSchedule(Schedule schedule) async {
    final data = await _send(
      'POST',
      '/api/schedules',
      body: schedule.toJson(includeId: true),
    ) as Map<String, dynamic>;
    return Schedule.fromJson(data);
  }

  Future<Schedule> updateSchedule(String id, Map<String, dynamic> changes) async {
    final data = await _send(
      'PATCH',
      '/api/schedules/$id',
      body: changes,
    ) as Map<String, dynamic>;
    return Schedule.fromJson(data);
  }

  Future<void> deleteSchedule(String id) async {
    await _send('DELETE', '/api/schedules/$id');
  }

  // --- TAREAS Y EXÁMENES (TASKS) ---

  Future<List<TaskItem>> getTasks({String? subjectId}) async {
    var path = '/api/tasks';
    if (subjectId != null) path += '?subjectId=${Uri.encodeComponent(subjectId)}';
    final list = await _send('GET', path) as List<dynamic>;
    return list.map((item) => TaskItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<TaskItem> createTask(TaskItem task) async {
    final data = await _send(
      'POST',
      '/api/tasks',
      body: task.toJson(includeId: true),
    ) as Map<String, dynamic>;
    return TaskItem.fromJson(data, localPhotoPath: task.localPhotoPath);
  }

  Future<TaskItem> updateTask(String id, Map<String, dynamic> changes) async {
    final data = await _send(
      'PATCH',
      '/api/tasks/$id',
      body: changes,
    ) as Map<String, dynamic>;
    return TaskItem.fromJson(data);
  }

  Future<void> deleteTask(String id) async {
    await _send('DELETE', '/api/tasks/$id');
  }

  // --- FALTAS (ABSENCES) ---

  Future<List<Absence>> getAbsences({String? subjectId}) async {
    var path = '/api/absences';
    if (subjectId != null) path += '?subjectId=${Uri.encodeComponent(subjectId)}';
    final list = await _send('GET', path) as List<dynamic>;
    return list.map((item) => Absence.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Absence> createAbsence(Absence absence) async {
    final data = await _send(
      'POST',
      '/api/absences',
      body: absence.toJson(includeId: true),
    ) as Map<String, dynamic>;
    return Absence.fromJson(data);
  }

  Future<Absence> updateAbsence(String id, Map<String, dynamic> changes) async {
    final data = await _send(
      'PATCH',
      '/api/absences/$id',
      body: changes,
    ) as Map<String, dynamic>;
    return Absence.fromJson(data);
  }

  Future<void> deleteAbsence(String id) async {
    await _send('DELETE', '/api/absences/$id');
  }

  // --- CALIFICACIONES (GRADES) ---

  Future<List<Grade>> getGrades({String? subjectId}) async {
    var path = '/api/grades';
    if (subjectId != null) path += '?subjectId=${Uri.encodeComponent(subjectId)}';
    final list = await _send('GET', path) as List<dynamic>;
    return list.map((item) => Grade.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Grade> createGrade(Grade grade) async {
    final data = await _send(
      'POST',
      '/api/grades',
      body: grade.toJson(includeId: true),
    ) as Map<String, dynamic>;
    return Grade.fromJson(data);
  }

  Future<Grade> updateGrade(String id, Map<String, dynamic> changes) async {
    final data = await _send(
      'PATCH',
      '/api/grades/$id',
      body: changes,
    ) as Map<String, dynamic>;
    return Grade.fromJson(data);
  }

  Future<void> deleteGrade(String id) async {
    await _send('DELETE', '/api/grades/$id');
  }

  // --- SUBIDA DE FOTOS (UPLOADS) ---

  static MediaType getMediaTypeForPath(String filePath) {
    final segments = filePath.toLowerCase().split('.');
    final ext = segments.length > 1 ? segments.last : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<String> uploadPhoto(File file) async {
    try {
      final url = Uri.parse('$_baseUrl/api/uploads');
      final request = http.MultipartRequest('POST', url);

      final token = await StorageService.instance.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final mediaType = getMediaTypeForPath(file.path);
      final multipartFile = await http.MultipartFile.fromPath(
        'photo',
        file.path,
        contentType: mediaType,
      );
      request.files.add(multipartFile);

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      final data = _processResponse(response) as Map<String, dynamic>;
      return data['url'] as String;
    } on SocketException {
      throw ApiException(statusCode: 0, message: 'Sin conexión con el servidor');
    } on http.ClientException {
      throw ApiException(statusCode: 0, message: 'Sin conexión con el servidor');
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Sin conexión con el servidor');
    }
  }

  // --- SYNC ---

  Future<Map<String, dynamic>> sync({String? since}) async {
    var path = '/api/sync';
    if (since != null && since.isNotEmpty) {
      path += '?since=${Uri.encodeComponent(since)}';
    }
    final data = await _send('GET', path) as Map<String, dynamic>;
    return data;
  }
}
