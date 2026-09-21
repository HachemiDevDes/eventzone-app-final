import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme/eventzone_theme.dart';
import 'screens/discovery_screen.dart';
import 'screens/events_screen.dart';
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
import 'widgets/subscription_expired_bottom_sheet.dart';
import 'screens/my_qr_code_screen.dart';
import 'screens/scan_qr_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'screens/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'screens/welcome_screen.dart';
import 'screens/email_signin_screen.dart';
import 'screens/email_signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/auth_providers.dart';
import 'dart:async';
import 'screens/profile_deep_link_handler_screen.dart';
import 'services/deep_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/settings_providers.dart';
import 'screens/settings/language_screen.dart';
import 'screens/settings/subscription_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/contact_screen.dart';
import 'screens/settings/support_screen.dart';
import 'screens/settings/terms_screen.dart';
import 'package:easy_localization/easy_localization.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

// Holds futures started before runApp() — init runs in parallel with Flutter engine
late final Future<List<Object?>> _appInitFuture;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool isNetworkError = details.exceptionAsString().toLowerCase().contains('socketexception') ||
                          details.exceptionAsString().toLowerCase().contains('clientexception') ||
                          details.exceptionAsString().toLowerCase().contains('failed host lookup');
    return Scaffold(
      backgroundColor: const Color(0xFF0F121E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isNetworkError ? Icons.wifi_off : Icons.error_outline, color: Colors.white54, size: 80),
              const SizedBox(height: 24),
              Text(
                isNetworkError ? "No Internet Connection" : "Oops, something went wrong!",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isNetworkError
                  ? "Please connect to the internet to use Eventzone."
                  : "We encountered an unexpected error. Please try again.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // 🚀 Kick off ALL inits BEFORE runApp() — they run in parallel with Flutter engine startup
  // By the time the first widget frame is built, these are already done or near-done.
  _appInitFuture = Future.wait([
    EasyLocalization.ensureInitialized(),   // parse translation JSON files
    Supabase.initialize(                     // set up Supabase client + restore session
      url: 'https://gknglowozpewwrtjumuc.supabase.co',
      publishableKey: 'sb_publishable_0bdK2TAGnlyUKCnloX1Dug_Sg5uedKc',
    ),
    SharedPreferences.getInstance(),         // read cached prefs from disk
  ]);

  // Fire-and-forget background tasks
  if (Platform.isAndroid) {
    FlutterDisplayMode.setHighRefreshRate().catchError((_) {});
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Firebase.initializeApp().then((_) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }).catchError((e) {
    debugPrint("Firebase not configured: $e");
    return null;
  });
  NotificationService().initialize().then((_) {
    NotificationService().scheduleDailyStreakNotifications();
  });

  // runApp() immediately — the app renders its first frame while inits are in flight
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: _appInitFuture,
      builder: (context, snapshot) {
        // While futures are in flight, show a seamless dark screen
        // (matches Android launch background — user sees no transition)
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFF0F121E),
              body: SizedBox.expand(),
            ),
          );
        }

        final prefs = snapshot.data![2] as SharedPreferences;

        // Setup deep links once ready
        DeepLinkService().onProfileIdFound = (profileId) {
          if (rootNavigatorKey.currentContext != null) {
            rootNavigatorKey.currentContext!.go('/profile?id=$profileId');
          }
        };
        DeepLinkService().initialize();

        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: EventzoneApp(),
          ),
        );
      },
    );
  }
}



final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final matchedLocation = state.matchedLocation;

      final isGoingToAuth = matchedLocation == '/welcome' ||
          matchedLocation == '/signin' ||
          matchedLocation == '/signup';

      if (!isLoggedIn) {
        return isGoingToAuth ? null : '/welcome';
      }

      // Check if profile data is still loading
      final profileAsync = ref.read(currentUserProvider);
      final isProfileLoading = profileAsync.isLoading;

      if (matchedLocation == '/') {
        if (isProfileLoading) return null; // Wait briefly while loading
        final onboardingCompleted = ref.read(onboardingStatusProvider);
        return onboardingCompleted ? '/home' : '/onboarding';
      }

      // While profile is loading, do NOT redirect the user anywhere else
      if (isLoggedIn && isProfileLoading) {
        return null;
      }

      // Now profile has loaded — read onboarding status
      final onboardingCompleted = ref.read(onboardingStatusProvider);

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
        builder: (context, state) => Scaffold(
          backgroundColor: const Color(0xFF0F121E),
          body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF7c3aed)),
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(),
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => EmailSignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => EmailSignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => MainNavigationHolder(),
      ),
      GoRoute(
        path: '/settings/language',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: LanguageScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/subscription',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: SubscriptionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/admin',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: AdminDashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/about',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: AboutScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/contact',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: ContactScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/support',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: SupportScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
          },
        ),
      ),
      GoRoute(
        path: '/settings/terms',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: TermsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation), child: child);
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
    ref.listen(currentUserProvider, (_, _) {
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

    return MaterialApp.router(
      title: 'Eventzone Attendee',
      debugShowCheckedModeBanner: false,
      theme: EventzoneTheme.getTheme(context.locale.languageCode),
      routerConfig: router,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
    );
  }
}

enum AppViewMode { global, event }

class MainNavigationHolder extends ConsumerStatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  ConsumerState<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends ConsumerState<MainNavigationHolder> {
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
          SnackBar(
            content: Text("Failed to register. Please try again.".tr()),
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
      builder: (context) => QRActionSheet(),
    );
    
    if (action != null && mounted) {
      if (action == 'my_qr') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => MyQRCodeScreen()));
      } else if (action == 'scan') {
        final subStatus = ref.read(subscriptionStatusProvider).valueOrNull;
        if (subStatus != null && !subStatus.isActive) {
          SubscriptionExpiredBottomSheet.show(context);
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (context) => ScanQRScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _currentMode == AppViewMode.global 
          ? _buildGlobalView() 
          : _buildEventView(),
      ),
      bottomNavigationBar: _buildBottomBar(),
      floatingActionButton: _buildBarScanButton(),
    );
  }

  Widget _buildGlobalView() {
    return FadeIndexedStack(
      index: _globalIndex,
      children: [
        DiscoveryScreen(
          onEventJoined: _onRegisterEvent,
          onAccessEvent: _onAccessEvent,
          events: _allEvents,
        ),
        EventsScreen(
          events: _allEvents,
          isLoading: _isLoading,
          onEventJoined: _onRegisterEvent,
          onAccessEvent: _onAccessEvent,
        ),
        LeaderboardAnalyticsScreen(),
        MyNetworkScreen(),
        SettingsScreen(),
      ],
    );
  }

  Widget _buildEventView() {
    if (_activeEvent == null) return SizedBox.shrink();
    
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
                decoration: BoxDecoration(
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
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Icon(LucideIcons.chevronLeft, color: Colors.white, size: 18),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeEvent!.title.toUpperCase(),
                            style: TextStyle(
                              
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Color(0xFF1A73E8), // Electric blue accent
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                isAtDashboard ? "Event Dashboard" : _getEventHubTabTitle(_eventIndex),
                                style: TextStyle(
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
      case 0: return "Dashboard".tr();
      case 1: return "My Agenda".tr();
      case 2: return "Attendee Networking".tr();
      case 3: return "Event Map".tr();
      case 4: return "Speakers".tr();
      case 5: return "Exhibitors".tr();
      case 6: return "Sponsors".tr();
      case 7: return "Sessions".tr();
      case 8: return "Connections".tr();
      default: return "Event Hub".tr();
    }
  }

  Widget _buildEventScreen() {
    switch (_eventIndex) {
      case 0: return EventDashboard(event: _activeEvent!, onNavigate: _navigateToEventIndex);
      case 1: return MyAgendaScreen(eventId: _activeEvent!.id);
      case 2: return NetworkingScreen(eventId: _activeEvent!.id);
      case 3: return MapScreen();
      case 4: return EventSpeakersScreen();
      case 5: return EventPartnersScreen(type: "Exhibitors");
      case 6: return EventPartnersScreen(type: "Sponsors");
      case 7: return EventSessionsScreen(eventId: _activeEvent!.id);
      case 8: return EventConnectionsScreen(eventId: _activeEvent!.id);
      default: return EventDashboard(event: _activeEvent!, onNavigate: _navigateToEventIndex);
    }
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
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
                _buildNavItem(LucideIcons.home, "Home".tr(), 0, true),
                _buildNavItem(LucideIcons.calendar, "Events".tr(), 1, true),
                _buildNavItem(LucideIcons.trophy, "Leaderboard".tr(), 2, true),
                _buildNavItem(LucideIcons.users, "Contacts".tr(), 3, true),
                _buildNavItem(LucideIcons.settings, "Settings".tr(), 4, true),
              ]
            : [
                _buildNavItem(LucideIcons.layoutDashboard, "Hub".tr(), 0, false),
                _buildNavItem(LucideIcons.calendarCheck, "My Agenda".tr(), 1, false),
                _buildNavItem(LucideIcons.users, "Connections".tr(), 8, false),
                _buildNavItem(LucideIcons.map, "Map".tr(), 3, false),
              ],
        ),
      ),
    );
  }

  Widget _buildBarScanButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final subStatus = ref.read(subscriptionStatusProvider).valueOrNull;
        if (subStatus != null && !subStatus.isActive) {
          SubscriptionExpiredBottomSheet.show(context);
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (context) => ScanQRScreen()));
      },
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.only(bottom: 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/scan_button_bg.svg',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            Icon(Icons.crop_free_rounded, color: EventzoneTheme.primaryAction, size: 28),
          ],
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
            SizedBox(height: 2),
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
