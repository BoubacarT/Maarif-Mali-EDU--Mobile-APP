class ApiConfig {
  /// URL du backend.
  /// - Développement local (Laragon) : valeur par défaut ci-dessous.
  /// - Production : compiler avec
  ///   `flutter build apk --dart-define=API_URL=https://votre-domaine.com`
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://maarif-learn-backend.test',
  );
  static const String apiPrefix = 'api';

  // ── Auth ──────────────────────────────────────────────────
  static String get loginUrl => '$baseUrl/$apiPrefix/login';
  static String get userUrl => '$baseUrl/$apiPrefix/user';

  // ── Cours & Matières ──────────────────────────────────────
  static String get subjectsUrl => '$baseUrl/$apiPrefix/subjects';
  static String subjectCoursesUrl(int subjectId) => '$baseUrl/$apiPrefix/subjects/$subjectId/courses';
  static String courseUrl(int id) => '$baseUrl/$apiPrefix/course/$id';

  // ── Module 1 — Parcours adaptatif ─────────────────────────
  static String lessonProgressUrl(int courseId) => '$baseUrl/$apiPrefix/lessons/$courseId/progress';
  static String lessonPrerequisiteStartUrl(int courseId) => '$baseUrl/$apiPrefix/lessons/$courseId/prerequisite/start';
  static String lessonPrerequisiteSubmitUrl(int courseId) => '$baseUrl/$apiPrefix/lessons/$courseId/prerequisite/submit';
  static String lessonEvaluationStartUrl(int courseId) => '$baseUrl/$apiPrefix/lessons/$courseId/evaluation/start';
  static String lessonEvaluationSubmitUrl(int courseId) => '$baseUrl/$apiPrefix/lessons/$courseId/evaluation/submit';

  // ── Module 2 — Examens blancs ─────────────────────────────
  static String get mockExamTemplatesUrl => '$baseUrl/$apiPrefix/mock-exams/templates';
  static String get mockExamSessionsUrl => '$baseUrl/$apiPrefix/mock-exams/sessions';
  static String mockExamSessionUrl(int id) => '$baseUrl/$apiPrefix/mock-exams/sessions/$id';

  // ── Module 3 — Plan d'étude ───────────────────────────────
  static String get studyPlanUrl => '$baseUrl/$apiPrefix/study-plan';
  static String get studyPlanWeekUrl => '$baseUrl/$apiPrefix/study-plan/week';
  static String get studyPlanGenerateUrl => '$baseUrl/$apiPrefix/study-plan/generate';
  static String studyPlanItemUrl(int id) => '$baseUrl/$apiPrefix/study-plan/items/$id';

  // ── Module 4 — Rapports ───────────────────────────────────
  static String get reportsCompletionUrl => '$baseUrl/$apiPrefix/reports/completion';
  static String get reportsMockExamsUrl => '$baseUrl/$apiPrefix/reports/mock-exams';
  static String get reportsProgressUrl => '$baseUrl/$apiPrefix/reports/progress';
  static String get reportsGoalsUrl => '$baseUrl/$apiPrefix/reports/goals';

  // ── Module 5 — Orientation & Objectifs ───────────────────
  static String get goalsUrl => '$baseUrl/$apiPrefix/goals';
  static String goalUrl(int id) => '$baseUrl/$apiPrefix/goals/$id';
  static String get institutionsUrl => '$baseUrl/$apiPrefix/institutions';
  static String get orientationTestsUrl => '$baseUrl/$apiPrefix/orientation/tests';
  static String orientationTestSubmitUrl(int id) => '$baseUrl/$apiPrefix/orientation/tests/$id/submit';

  // ── Module 6 — MAARIFA AI ─────────────────────────────────
  static String get arifRecommendationsUrl => '$baseUrl/$apiPrefix/ai/recommendations';
  static String arifMarkReadUrl(int id) => '$baseUrl/$apiPrefix/ai/recommendations/$id/read';
  static String get arifConversationsUrl => '$baseUrl/$apiPrefix/ai/conversations';
  static String arifConversationMessagesUrl(int id) => '$baseUrl/$apiPrefix/ai/conversations/$id/messages';
  static String get arifStatsUrl => '$baseUrl/$apiPrefix/ai/stats';
  static String get arifGamificationUrl => '$baseUrl/$apiPrefix/ai/gamification';
  static String get arifPredictBacUrl => '$baseUrl/$apiPrefix/ai/predict-bac';
  static String courseSummarizeUrl(int id) => '$baseUrl/$apiPrefix/ai/courses/$id/summarize';
  static String courseFlashcardsUrl(int id) => '$baseUrl/$apiPrefix/ai/courses/$id/flashcards';
  static String courseExerciseUrl(int id) => '$baseUrl/$apiPrefix/ai/courses/$id/exercise';

  /// URL générique
  static String url(String path) => '$baseUrl/$apiPrefix$path';
}
