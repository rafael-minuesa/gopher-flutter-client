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
