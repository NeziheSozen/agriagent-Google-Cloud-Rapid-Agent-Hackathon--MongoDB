import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/l10n/translations.dart';
import '../app/theme.dart';
import '../widgets/glass_card.dart';
import '../providers/farmer_provider.dart';
import '../services/farmer_api.dart';
import '../utils/app_logger.dart';
import '../providers/locale_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.tr(context, 'enter_email_error'))),
      );
      return;
    }

    final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

    if (!isEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.tr(context, 'invalid_email_error'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(farmerApiProvider);
      final profile = await api.login(email);
      
      if (mounted) {
        // Save session persistently
        AppTracker.info('Login success for: ${profile.userId}');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_in_user_id', profile.userId);
        
        ref.read(selectedFarmerIdProvider.notifier).set(profile.userId);
        
        final hasSeenOfflineSetup = prefs.getBool('offline_setup_shown') ?? false;
        context.go(hasSeenOfflineSetup ? '/' : '/offline-setup');
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        AppTracker.warn('Login attempt failed: $errStr');
        if (errStr.contains('404') || errStr.contains('not found') || errStr.contains('Profile not found')) {
          context.go('/onboarding');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${L10n.tr(context, 'login_failed')}: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Removed to use Scaffold's theme background)
          // Subtle glow effects
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                // blur is not directly supported via container, use image filter if needed
              ),
            ),
          ),


          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo / Icon
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                              ),
                              child: Icon(Icons.spa_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 32),
                            
                            Text(
                              'AgriAgent',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              L10n.tr(context, 'login_subtitle'),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 48),
                            
                            // Login Card
                            GlassCard(
                              padding: const EdgeInsets.all(32),
                              showGradientBorder: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    L10n.tr(context, 'create_or_login'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  TextFormField(
                                    controller: _emailController,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                    decoration: InputDecoration(
                                      hintText: L10n.tr(context, 'enter_email'),
                                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 8,
                                      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    ),
                                    child: _isLoading 
                                      ? const SizedBox(
                                          width: 24, height: 24, 
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                        )
                                      : Text(
                                          L10n.tr(context, 'connect_to_farm'),
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    context.go('/onboarding');
                                  },
                                  child: Text(
                                    L10n.tr(context, 'create_new_profile'),
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Language Selector
          Positioned(
            top: 48,
            right: 16,
            child: SafeArea(
              child: _buildLanguageDropdown(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider); // Rebuild when locale changes
    final currentLang = Localizations.localeOf(context).languageCode;
    final supportedLocales = const [
      'en', 'tr', 'nl', 'es', 'it', 'ja', 'ko', 'fr', 'pt', 'hi', 'zh'
    ];

    final localeNames = {
      'en': 'English',
      'tr': 'Türkçe',
      'nl': 'Nederlands',
      'es': 'Español',
      'it': 'Italiano',
      'ja': '日本語',
      'ko': '한국어',
      'fr': 'Français',
      'pt': 'Português',
      'hi': 'हिन्दी',
      'zh': '中文',
    };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: supportedLocales.contains(currentLang) ? currentLang : 'en',
          icon: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 20),
          isDense: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: supportedLocales.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  localeNames[lang] ?? lang,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(localeProvider.notifier).setLocale(Locale(val));
            }
          },
        ),
      ),
    );
  }
}
