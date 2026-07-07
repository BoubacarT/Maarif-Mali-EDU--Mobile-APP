import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/HomePage.dart';
import 'package:maarif_learn/services/auth_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';
import 'package:maarif_learn/widgets/maarif_brand_title.dart';

class Pagelogin extends StatefulWidget {
  const Pagelogin({super.key});

  @override
  State<Pagelogin> createState() => _PageloginState();
}

class _PageloginState extends State<Pagelogin> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slideLogo;
  late Animation<Offset> _slideCard;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fade = CurvedAnimation(parent: _anim, curve: const Interval(0, 0.65, curve: Curves.easeOutCubic));
    _slideLogo = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: const Interval(0, 0.55, curve: Curves.easeOutCubic)),
    );
    _slideCard = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic)),
    );
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width > 520 ? 440.0 : size.width - 40;

    return Scaffold(
      body: Stack(
        children: [
          _LoginBackground(height: size.height),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slideLogo,
                          child: Column(
                            children: [
                              _LogoRing(),
                              const SizedBox(height: 20),
                              const MaarifBrandTitle(size: 34),
                              const SizedBox(height: 8),
                              Text(
                                'Écoles Maarif de Türkiye · Mali',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Portail élève — apprentissage en ligne',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slideCard,
                          child: _LoginCard(
                            formKey: _formKey,
                            obscureText: _obscureText,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            onTogglePassword: () => setState(() => _obscureText = !_obscureText),
                            onEmailSaved: (v) => _email = v ?? '',
                            onPasswordSaved: (v) => _password = v ?? '',
                            onSubmit: _submit,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '© ${DateTime.now().year} Maarif Learn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(_email, _password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const Homepage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (e.statusCode == 403 && e.message.contains('élèves')) {
        setState(() {
          _errorMessage =
              'Ce compte n\'est pas un compte élève. Utilisez l\'application mobile avec un compte élève.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('Connection')
            ? 'Impossible de joindre le serveur. Vérifiez votre connexion.'
            : 'Une erreur est survenue. Réessayez.';
        _isLoading = false;
      });
    }
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
          Positioned(
            top: -80,
            right: -60,
            child: _GlowBlob(diameter: 220, color: AppColors.teal.withValues(alpha: 0.25)),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: _GlowBlob(diameter: 180, color: AppColors.tealLight.withValues(alpha: 0.12)),
          ),
          Positioned(
            bottom: -60,
            right: -20,
            child: _GlowBlob(diameter: 200, color: Colors.white.withValues(alpha: 0.06)),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _LogoRing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Hero(
        tag: 'maarif_logo',
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/maarif_logo.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: AppColors.navyLight,
                alignment: Alignment.center,
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.obscureText,
    required this.isLoading,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onEmailSaved,
    required this.onPasswordSaved,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final bool obscureText;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final void Function(String?) onEmailSaved;
  final void Function(String?) onPasswordSaved;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.waving_hand_rounded, color: AppColors.teal, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Connectez-vous pour accéder à vos cours',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: GoogleFonts.plusJakartaSans(),
                decoration: InputDecoration(
                  labelText: 'Adresse e-mail',
                  hintText: 'nom@exemple.com',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.teal),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Champ obligatoire';
                  if (!value.contains('@')) return 'E-mail invalide';
                  return null;
                },
                onSaved: onEmailSaved,
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: obscureText,
                autofillHints: const [AutofillHints.password],
                style: GoogleFonts.plusJakartaSans(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.teal),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onTogglePassword,
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
                onSaved: onPasswordSaved,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.red.shade900,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isLoading ? null : onSubmit,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Accéder à mon espace',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Espace réservé aux comptes élèves',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
