import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/home_stats_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<HomeStatsProvider>().load(auth.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final statsProvider = context.watch<HomeStatsProvider>();
    final stats = statsProvider.stats;

    return Scaffold(
      body: SafeArea(
        child: statsProvider.loading
            ? const Center(child: CircularProgressIndicator())
            : statsProvider.error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(statsProvider.error!,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<HomeStatsProvider>()
                              .load(auth.userId!),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Ekota Builder',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'logout') {
                              await context.read<AuthProvider>().logout();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'logout',
                              child: Text('Logout'),
                            ),
                          ],
                          child: const CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.inputFill,
                            child: Icon(Icons.person,
                                size: 44, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          auth.name ?? 'Producer',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          auth.role ?? '',
                          style: const TextStyle(
                              color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 32),
                        if (stats != null) _statGrid(stats),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () =>
            Navigator.pushNamed(context, '/producer/items/create'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _statGrid(stats) {
    Widget box(String value, String label, IconData icon) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70),
              ),
            ]),
          ),
        );

    return Column(children: [
      Row(children: [
        box(stats.gigsCompleted.toString().padLeft(2, '0'),
            'Gigs\nCompleted', Icons.check_circle_outline),
        box(stats.gigsCurrentlyListed.toString().padLeft(2, '0'),
            'Gigs\nListed', Icons.list_alt),
      ]),
      Row(children: [
        box(stats.investors.toString().padLeft(2, '0'),
            'Investors', Icons.people_outline),
        box(stats.rating.toStringAsFixed(1), 'Rating', Icons.star_outline),
      ]),
    ]);
  }
}
