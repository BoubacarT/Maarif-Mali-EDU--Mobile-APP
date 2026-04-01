class ApiConfig {
  static const String baseUrl = 'https://lafiasugubackend.com';
  static const String apiPrefix = 'api';

  static String get loginUrl => '$baseUrl/$apiPrefix/login';
  static String get userUrl => '$baseUrl/$apiPrefix/user';
  static String get subjectsUrl => '$baseUrl/$apiPrefix/subjects';
  static String subjectCoursesUrl(int subjectId) => '$baseUrl/$apiPrefix/subjects/$subjectId/courses';
  static String courseUrl(int id) => '$baseUrl/$apiPrefix/course/$id';

  /// URL complète pour une route donnée
  static String url(String path) => '$baseUrl/$apiPrefix$path';
}
