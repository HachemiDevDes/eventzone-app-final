import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/eventzone_theme.dart';
import 'screens/discovery_screen.dart';
import 'screens/event_dashboard.dart';
import 'screens/networking_screen.dart';
import 'screens/map_screen.dart';
import 'screens/leaderboard_analytics_screen.dart';
import 'screens/my_network_screen.dart';
import 'screens/event_partners_screen.dart';
import 'screens/event_sessions_screen.dart';
import 'screens/event_speakers_screen.dart';
import 'screens/my_agenda_screen.dart';
import 'screens/event_connections_screen.dart';
import 'models/event_model.dart';
import 'widgets/qr_action_sheet.dart';
import 'screens/my_qr_code_screen.dart';
import 'screens/scan_qr_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/email_signin_screen.dart';
import 'screens/email_signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/auth_providers.dart';
import 'dart:async';
import 'screens/profile_deep_link_handler_screen.dart';
import 'services/deep_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/settings_providers.dart';
import 'screens/settings/language_screen.dart';
import 'screens/settings/subscription_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/contact_screen.dart';
import 'screens/settings/support_screen.dart';
import 'screens/settings/terms_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  await Supabase.initialize(
    url: 'https://awkreadldqmidcrrqukm.supabase.co',
    publishableKey: 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z',
  );

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase not configured: $e");
  }
  await NotificationService().initialize();
  await NotificationService().scheduleDailyStreakNotifications();

  // Initialize DeepLinkService for deferred deep links
  DeepLinkService().onProfileIdFound = (profileId) {
    if (rootNavigatorKey.currentContext != null) {
      rootNavigatorKey.currentContext!.go('/profile?id=$profileId');
    }
  };
  DeepLinkService().initialize();

  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const EventzoneApp(),
  ));
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = ref.read(authStateProvider).value;
      final onboardingCompleted = ref.read(onboardingStatusProvider);
      final isLoggedIn = user != null;
      final matchedLocation = state.matchedLocation;

      // Allow Splash screen to run its course
      if (matchedLocation == '/') return null;

      final isGoingToAuth = matchedLocation == '/welcome' ||
          matchedLocation == '/signin' ||
          matchedLocation == '/signup';

      // Check if profile data is still loading
      final profileAsync = ref.read(currentUserProvider);
      final isProfileLoading = profileAsync.isLoading;

      if (!isLoggedIn) {
        return isGoingToAuth ? null : '/welcome';
      }

      // If logged in and profile is still loading, wait on splash screen
      if (isLoggedIn && isProfileLoading) {
        return matchedLocation == '/' ? null : '/';
      }

      // If logged in but not onboarded, redirect to onboarding
      if (isLoggedIn && !onboardingCompleted) {
        return matchedLocation == '/onboarding' ? null : '/onboarding';
      }

      // If logged in and onboarded, redirect home from auth/onboarding screens
      if (isLoggedIn && onboardingCompleted) {
        if (isGoingToAuth || matchedLocation == '/onboarding') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const EmailSignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const EmailSignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainNavigationHolder(),
      ),
      GoRoute(
        path: '/settings/language',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const LanguageScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/subscription',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const SubscriptionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AboutScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/contact',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ContactScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/support',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const SupportScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/terms',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const TermsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfileDeepLinkHandlerScreen(
          profileId: state.uri.queryParameters['id'],
        ),
      ),
    ],
  );
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  GoRouterRefreshNotifier(Ref ref) {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });

    // Listen to profile state changes to trigger GoRouter redirection logic
    // This ensures we always re-evaluate when the profile finishes loading
    ref.listen(currentUserProvider, (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class EventzoneApp extends ConsumerWidget {
  const EventzoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'Eventzone Attendee',
      debugShowCheckedModeBanner: false,
      theme: EventzoneTheme.darkTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
        Locale('ar', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

enum AppViewMode { global, event }

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _globalIndex = 0;
  int _eventIndex = 0;
  AppViewMode _currentMode = AppViewMode.global;
  EventModel? _activeEvent;
  final List<EventModel> _registeredEvents = [];
  List<EventModel> _allEvents = [];
  bool _isLoading = true;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final events = await _supabaseService.fetchEvents();
    setState(() {
      _allEvents = events;
      _registeredEvents.clear();
      _registeredEvents.addAll(events.where((e) => e.isJoined));
      _isLoading = false;
    });
  }

  Future<void> _onRegisterEvent(EventModel event) async {
    if (event.isJoined) {
      _onAccessEvent(event);
      return;
    }
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;
    setState(() => _isLoading = true);
    final success = await _supabaseService.registerForEvent(event.id, currentUserId);
    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        event.isJoined = true;
        if (!_registeredEvents.contains(event)) {
          _registeredEvents.add(event);
        }
        _globalIndex = 1;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Registered for ${event.title}!"),
            backgroundColor: EventzoneTheme.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to register. Please try again."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onAccessEvent(EventModel event) {
    setState(() {
      _activeEvent = event;
      _currentMode = AppViewMode.event;
      _eventIndex = 0;
    });
  }

  void _exitEvent() {
    setState(() {
      _currentMode = AppViewMode.global;
    });
  }

  void _navigateToEventIndex(int index) {
    setState(() {
      _eventIndex = index;
    });
  }

  void _showQRMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QRActionSheet(),
    );
    
    if (action != null && mounted) {
      if (action == 'my_qr') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MyQRCodeScreen()));
      } else if (action == 'scan') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanQRScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentMode == AppViewMode.global 
          ? _buildGlobalView() 
          : _buildEventView(),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGlobalView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction));
    }

    return FadeIndexedStack(
      index: _globalIndex,
      children: [
        DiscoveryScreen(
          onEventJoined: _onRegisterEvent,
          onAccessEvent: _onAccessEvent,
          events: _allEvents,
        ),
        const LeaderboardAnalyticsScreen(),
        const MyNetworkScreen(),
        const SettingsScreen(),
      ],
    );
  }

  Widget _buildEventView() {
    if (_activeEvent == null) return const SizedBox.shrink();
    
    final isAtDashboard = _eventIndex == 0;
    
    return Stack(
      children: [
        _buildEventScreen(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xCC060913), // Semitransparent deep navy matching theme
                  border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: isAtDashboard 
                          ? _exitEvent 
                          : () {
                              setState(() {
                                _eventIndex = 0;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeEvent!.title.toUpperCase(),
                            style: const TextStyle(
                              
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A73E8), // Electric blue accent
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAtDashboard ? "Event Dashboard" : _getEventHubTabTitle(_eventIndex),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getEventHubTabTitle(int index) {
    switch (index) {
      case 0: return "Dashboard";
      case 1: return "My Agenda";
      case 2: return "Attendee Networking";
      case 3: return "Event Map";
      case 4: return "Speakers";
      case 5: return "Exhibitors";
      case 6: return "Sponsors";
      case 7: return "Sessions";
      case 8: return "Connections";
      default: return "Event Hub";
    }
  }

  Widget _buildEventScreen() {
    switch (_eventIndex) {
      case 0: return EventDashboard(event: _activeEvent!, onNavigate: _navigateToEventIndex);
      case 1: return MyAgendaScreen(eventId: _activeEvent!.id);
      case 2: return NetworkingScreen(eventId: _activeEvent!.id);
      case 3: return const MapScreen();
      case 4: return const EventSpeakersScreen();
      case 5: return const EventPartnersScreen(type: "Exhibitors");
      case 6: return const EventPartnersScreen(type: "Sponsors");
      case 7: return EventSessionsScreen(eventId: _activeEvent!.id);
      case 8: return EventConnectionsScreen(eventId: _activeEvent!.id);
      default: return EventDashboard(event: _activeEvent!, onNavigate: _navigateToEventIndex);
    }
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: EventzoneTheme.backgroundEnd,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        height: 70, // Fixed height to avoid overflow
        padding: EdgeInsets.zero,
        notchMargin: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _currentMode == AppViewMode.global 
            ? [
                _buildNavItem(LucideIcons.home, "Home", 0, true),
                _buildNavItem(LucideIcons.trophy, "Leaderboard", 1, true),
                _buildBarScanButton(),
                _buildNavItem(LucideIcons.users, "Contacts", 2, true),
                _buildNavItem(LucideIcons.settings, "Settings", 3, true),
              ]
            : [
                _buildNavItem(LucideIcons.layoutDashboard, "Hub", 0, false),
                _buildNavItem(LucideIcons.calendarCheck, "My Agenda", 1, false),
                _buildBarScanButton(),
                _buildNavItem(LucideIcons.users, "Connections", 8, false),
                _buildNavItem(LucideIcons.map, "Map", 3, false),
              ],
        ),
      ),
    );
  }

  Widget _buildBarScanButton() {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showQRMenu();
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: EventzoneTheme.primaryAction,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(LucideIcons.scan, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isGlobal) {
    final bool isSelected = (isGlobal ? _globalIndex : _eventIndex) == index;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isGlobal) {
            _globalIndex = index;
          } else {
            _eventIndex = index;
          }
        });
      },
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? EventzoneTheme.primaryAction : Colors.white38,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? EventzoneTheme.primaryAction : Colors.white38,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}
