import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/theme/app_theme.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: kIsWeb, // actif uniquement sur web (Chrome)
      defaultDevice: Devices.ios.iPhone13,
      tools: const [
        ...DevicePreview.defaultTools,
      ],
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MaarifMaliEdu',
      theme: AppTheme.light(),
      home: const Pagelogin(),
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
