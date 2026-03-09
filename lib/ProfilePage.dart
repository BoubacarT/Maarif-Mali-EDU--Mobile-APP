import 'package:flutter/material.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StudentProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await AuthStorage.getToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Session expiree. Reconnectez-vous.';
      });
      return;
    }

    try {
      final profile = await ProfileService.getProfile(token);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on ProfileException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors du chargement du profil.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00ADBB)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final p = _profile;
    if (p == null) {
      return const Center(child: Text('Aucune information de profil.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes profils',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _infoCard('Nom complet', _fullName(p)),
          _infoCard('Email', p.email),
          _infoCard('Niveau', p.level?['name']?.toString() ?? '-'),
          _infoCard('Adresse', p.adresse ?? '-'),
          _infoCard('Date de naissance', p.dateNaissance ?? '-'),
        ],
      ),
    );
  }

  String _fullName(StudentProfile p) {
    final prenom = (p.prenom ?? '').trim();
    final nom = (p.nom ?? '').trim();
    final full = '$prenom $nom'.trim();
    if (full.isNotEmpty) return full;
    return p.name;
  }

  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
