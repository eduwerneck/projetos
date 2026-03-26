import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/session/new_session_screen.dart';
import '../screens/session/session_detail_screen.dart';
import '../screens/capture/capture_screen.dart';
import '../screens/upload/upload_screen.dart';
import '../screens/results/results_screen.dart';
import '../models/session.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/session/new',
      name: 'new-session',
      builder: (context, state) => const NewSessionScreen(),
    ),
    GoRoute(
      path: '/session/:id',
      name: 'session-detail',
      builder: (context, state) {
        final session = state.extra as FieldSession;
        return SessionDetailScreen(session: session);
      },
    ),
    GoRoute(
      path: '/session/:id/capture',
      name: 'capture',
      builder: (context, state) {
        final session = state.extra as FieldSession;
        return CaptureScreen(session: session);
      },
    ),
    GoRoute(
      path: '/session/:id/upload',
      name: 'upload',
      builder: (context, state) {
        final session = state.extra as FieldSession;
        return UploadScreen(session: session);
      },
    ),
    GoRoute(
      path: '/session/:id/results',
      name: 'results',
      builder: (context, state) {
        final session = state.extra as FieldSession;
        return ResultsScreen(session: session);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Página não encontrada: ${state.error}'),
    ),
  ),
);
