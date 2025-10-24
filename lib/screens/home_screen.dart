import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/address_bar.dart';
import '../widgets/menu_view.dart';
import '../widgets/text_view.dart';
import 'bookmarks_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Simplified web version - just show landing page
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gopher Client'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const WebLandingPage(),
      );
    }

    // Full native version with all features
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gopher Client'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<AppState>(
            builder: (context, state, child) {
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: state.canGoBack ? () => state.goBack() : null,
                tooltip: 'Back',
              );
            },
          ),
          Consumer<AppState>(
            builder: (context, state, child) {
              return IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: state.canGoForward ? () => state.goForward() : null,
                tooltip: 'Forward',
              );
            },
          ),
          Consumer<AppState>(
            builder: (context, state, child) {
              final url = state.currentAddress?.toUrl();
              if (url == null) return const SizedBox.shrink();

              return FutureBuilder<bool>(
                future: state.isBookmarked(url),
                builder: (context, snapshot) {
                  final isBookmarked = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: () => _toggleBookmark(context, state, url),
                    tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                  );
                },
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          BrowserTab(),
          BookmarksScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.public),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    AppState state,
    String url,
  ) async {
    final isBookmarked = await state.isBookmarked(url);

    if (isBookmarked) {
      await state.removeBookmark(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark removed')),
        );
      }
    } else {
      await _showBookmarkDialog(context, state, url);
    }
  }

  Future<void> _showBookmarkDialog(
    BuildContext context,
    AppState state,
    String url,
  ) async {
    final controller = TextEditingController(text: url);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await state.addBookmark(result, url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark added')),
        );
      }
    }
  }
}

class BrowserTab extends StatelessWidget {
  const BrowserTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AddressBar(),
        Expanded(
          child: Consumer<AppState>(
            builder: (context, state, child) {
              if (state.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: state.clearError,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state.currentMenu != null) {
                return MenuView(items: state.currentMenu!);
              }

              if (state.currentContent != null) {
                return TextView(content: state.currentContent!);
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.public,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to Gopher',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter a gopher:// URL above to start browsing',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Example servers:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _ExampleLink('gopher://gopher.floodgap.com'),
                    _ExampleLink('gopher://gopher.quux.org'),
                    _ExampleLink('gopher://gopherpedia.com'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExampleLink extends StatelessWidget {
  final String url;

  const _ExampleLink(this.url);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        context.read<AppState>().navigate(url);
      },
      child: Text(url),
    );
  }
}

/// Web landing page - simplified UI for web platform
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.public,
                size: 96,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Gopher Client',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A modern, cross-platform Gopher protocol client',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Web Version Limitation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The Gopher protocol requires raw TCP socket connections, '
                      'which web browsers do not support for security reasons.',
                      style: TextStyle(color: Colors.orange.shade900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To browse Gopher servers, please download the desktop or mobile version.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.download,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Download Now',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _DownloadButton(
                          icon: Icons.desktop_windows,
                          label: 'Windows',
                          url: 'https://github.com/rafael-minuesa/gopher-flutter-client/releases',
                        ),
                        _DownloadButton(
                          icon: Icons.apple,
                          label: 'macOS',
                          url: 'https://github.com/rafael-minuesa/gopher-flutter-client/releases',
                        ),
                        _DownloadButton(
                          icon: Icons.laptop,
                          label: 'Linux',
                          url: 'https://github.com/rafael-minuesa/gopher-flutter-client/releases',
                        ),
                        _DownloadButton(
                          icon: Icons.android,
                          label: 'Android',
                          url: 'https://github.com/rafael-minuesa/gopher-flutter-client/releases',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Features',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _FeatureItem(
                icon: Icons.speed,
                title: 'Fast & Lightweight',
                description: 'Native performance on all platforms',
              ),
              _FeatureItem(
                icon: Icons.bookmark,
                title: 'Bookmarks & History',
                description: 'Save your favorite Gopher sites',
              ),
              _FeatureItem(
                icon: Icons.search,
                title: 'Full Protocol Support',
                description: 'Browse directories, files, and search servers',
              ),
              _FeatureItem(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                description: 'Beautiful UI with dark mode support',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _DownloadButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        // In a real app, would use url_launcher
        // For now, just show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visit GitHub releases to download $label version'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      },
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
