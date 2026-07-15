import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:maarif_learn/CourseDetailPage.dart';
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Recherche globale dans les cours du niveau de l'élève.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.length < 2) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final token = await AuthStorage.getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.url('/search')}?q=${Uri.encodeQueryComponent(q)}'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        setState(() {
          _results = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
          _searched = true;
        });
      } else {
        setState(() { _loading = false; _searched = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _searched = true; });
    }
  }

  Color _subjectColor(Map<String, dynamic> course) {
    final hex = (course['subject'] as Map?)?['color']?.toString() ?? '#00ADBB';
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
          cursorColor: AppColors.teal,
          decoration: InputDecoration(
            hintText: 'Rechercher un cours…',
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 15),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
              onPressed: () {
                _ctrl.clear();
                setState(() { _results = []; _searched = false; });
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3))
          : !_searched
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_rounded, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Tape au moins 2 lettres pour chercher\nparmi tes cours.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.5)),
                  ]),
                )
              : _results.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Aucun cours trouvé pour « ${_ctrl.text.trim()} »',
                            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final c = _results[i];
                        final color = _subjectColor(c);
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CourseDetailPage(courseId: c['id'] as int)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.menu_book_rounded, color: color, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c['title']?.toString() ?? '',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                                        Text((c['subject'] as Map?)?['name']?.toString() ?? '',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5, color: AppColors.textSecondary)),
                                      ]),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
