/// Configuration de l'API Maarif-Backend (Laravel)
/// Backend: C:\Users\Opo\Documents\maarif-backend
///
/// Pour l'émulateur Android : http://10.0.2.2:8000
/// Pour un appareil physique : http://VOTRE_IP:8000
/// Démarrer le backend : php artisan serve
class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String apiPrefix = '/api';

  static String get loginUrl => '$baseUrl$apiPrefix/login';
  static String get userUrl => '$baseUrl$apiPrefix/user';
  static String get subjectsUrl => '$baseUrl$apiPrefix/subjects';
  static String subjectCoursesUrl(int subjectId) => '$baseUrl$apiPrefix/subjects/$subjectId/courses';
  static String courseUrl(int id) => '$baseUrl$apiPrefix/course/$id';

  /// URL complète pour une route donnée
  static String url(String path) => '$baseUrl$apiPrefix$path';
}
