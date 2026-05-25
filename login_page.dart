import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'agrilink/app_state.dart';
import 'agrilink/theme.dart';
import 'agrilink/screens/login_screen.dart';
import 'auth_service.dart';
import 'signup_page.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void login() async {
  if (emailController.text.isEmpty || passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez remplir tous les champs')),
    );
    return;
  }

  setState(() => isLoading = true);

  final result = await AuthService.signin(
    email: emailController.text,
    password: passwordController.text,
    appType: "iot",
  );

  setState(() => isLoading = false);

  if (result["success"] == true) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result["message"])),
    );
  }
}

  void goToAgriLink() {
    final agriState = AppState();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AgriLinkWrapper(agriState: agriState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.mediumGreen, AppColors.lightGreen],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.mediumGreen.withOpacity(0.3),
                        blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Center(
                  child: Text('🌱', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Station IoT Agricole',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                'Surveillez vos cultures en temps réel',
                style: TextStyle(fontSize: 13, color: AppColors.softGreen),
              ),
              const SizedBox(height: 40),

              // ── Champs login ──
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Identifiant',
                  prefixIcon: const Icon(Icons.person, color: AppColors.lightGreen),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.mediumGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock, color: AppColors.lightGreen),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.mediumGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Bouton IoT ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : login,
                  icon: const Icon(Icons.sensors, color: Colors.white),
                  label: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Accéder au Dashboard IoT',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Séparateur ──
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou',
                        style: TextStyle(color: Colors.grey.shade400)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 16),
//button signup 
const SizedBox(height: 12),

TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
  },
  child: const Text("Créer un compte"),
),
              // ── Bouton AgriLink ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: goToAgriLink,
                  icon: const Text('🌍', style: TextStyle(fontSize: 20)),
                  label: const Text(
                    'Rejoindre AgriLink Communauté',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mediumGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.mediumGreen, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Badge communauté ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGreen),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('👥', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('+1,200 agriculteurs sur AgriLink',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGreen,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

// ── Wrapper AgriLink avec son propre state ────────────────────────────────────
class _AgriLinkWrapper extends StatefulWidget {
  final AppState agriState;
  const _AgriLinkWrapper({required this.agriState});

  @override
  State<_AgriLinkWrapper> createState() => _AgriLinkWrapperState();
}

class _AgriLinkWrapperState extends State<_AgriLinkWrapper> {
  @override
  void initState() {
    super.initState();
    widget.agriState.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen(state: widget.agriState);
  }
}