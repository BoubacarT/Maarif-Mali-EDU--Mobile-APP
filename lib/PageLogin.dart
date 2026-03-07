import 'package:flutter/material.dart';
import 'package:maarif_learn/HomePage.dart';
import 'package:maarif_learn/services/auth_service.dart';

class Pagelogin extends StatefulWidget {
  const Pagelogin({super.key});

  @override
  State<Pagelogin> createState() => _PageloginState();
}

class _PageloginState extends State<Pagelogin> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF00ADBB),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                  color: Colors.white
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset("assets/images/footer_logo.png",
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Text("Maarif Mali",
                style: TextStyle(fontSize: 32, color: Colors.white,fontWeight: FontWeight.bold),),
              Text("Badalabougou", style: TextStyle(color: Colors.white, fontSize: 10),),
              Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Connexion Élève",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 25),

                    /// FORMULAIRE
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          /// EMAIL
                          TextFormField(
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return "Champ obligatoire";
                              if (!value.contains('@')) return "Email invalide";
                              return null;
                            },
                            onSaved: (value) => _email = value!,
                          ),
                          SizedBox(height: 15),

                          /// PASSWORD
                          TextFormField(
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              hintText: "Mot de passe",
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) =>
                            value!.isEmpty ? "Champ obligatoire" : null,
                            onSaved: (value) => _password = value!,
                          ),

                          /// Message d'erreur
                          if (_errorMessage != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 15),
                          ],

                          SizedBox(height: 25),

                          /// BOUTON CONNEXION
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF00ADBB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(Icons.login, color: Colors.white),
                              label: Text(
                                _isLoading ? "Connexion..." : "Se connecter",
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
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
                                            MaterialPageRoute(
                                              builder: (context) => const Homepage(),
                                            ),
                                          );
                                        } on AuthException catch (e) {
                                          if (e.statusCode == 403 && e.message.contains('élèves')) {
                                            setState(() {
                                              _errorMessage = 'Ce compte n\'est pas un compte élève. Utilisez l\'application mobile avec un compte élève.';
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
                                                ? 'Impossible de joindre le serveur. Vérifiez que le backend Maarif est démarré.'
                                                : 'Une erreur est survenue. Réessayez.';
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


