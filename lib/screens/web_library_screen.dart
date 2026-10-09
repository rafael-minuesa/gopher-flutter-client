import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/native_companion.dart';
import '../companion/client.dart';

class WebLibraryScreen extends StatefulWidget {
  final CompanionClient? client;
  const WebLibraryScreen({super.key, this.client});
  @override
  State<WebLibraryScreen> createState() => _WebLibraryScreenState();
}

class _WebLibraryScreenState extends State<WebLibraryScreen> {
  List<dynamic> _pages = [];
  String? _error;
  bool _loading = true;
  CompanionClient get _client => widget.client ?? NativeCompanion.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.request({'action': 'list'}, start: true);
      if (mounted) {
        setState(() {
          _pages = result['pages'] as List;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> page) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved copy?'),
        content: Text(page['title'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await _client.request({'action': 'remove', 'id': page['id']});
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _client.request({'action': 'stop'});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Local Gopher serving stopped. Saved copies are kept.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Saved web pages'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh library',
        ),
        TextButton(
          onPressed: _loading || _error != null ? null : _stop,
          child: const Text('Stop serving'),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Copies sent from Gopher Reader are saved on this computer and served at 127.0.0.1:7070. Opening this library starts local serving.',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_error!),
                ),
              if (_error != null)
                TextButton(onPressed: _load, child: const Text('Try again')),
              if (_pages.isEmpty && _error == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Open a page in Gopher Reader and choose Open in Gopher app. Article, full-page text, and links are saved together.',
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index] as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(page['title'] as String),
                      subtitle: Text(page['source'] as String),
                      onTap: page['url'] == null
                          ? null
                          : () {
                              final state = context.read<AppState>();
                              Navigator.pop(context);
                              state.selectTab(0);
                              state.navigate(
                                page['url'] as String,
                                title: page['title'] as String,
                              );
                            },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove saved copy',
                        onPressed: () => _remove(page),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}
