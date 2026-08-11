import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/groups/groups_screen.dart';
import '../../presentation/screens/groups/group_detail_screen.dart';
import '../../presentation/screens/attendance/attendance_screen.dart';
import '../../presentation/screens/grades/grades_screen.dart';
import '../../presentation/screens/planner/planner_screen.dart';
import '../../presentation/screens/export/export_screen.dart';
import '../../presentation/screens/workshop/workshop_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) => GroupDetailScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: '/attendance/:groupId',
        builder: (context, state) => AttendanceScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: '/grades/:groupId',
        builder: (context, state) => GradesScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) => const PlannerScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/workshop',
        builder: (context, state) => const WorkshopScreen(),
      ),
    ],
  );
});
