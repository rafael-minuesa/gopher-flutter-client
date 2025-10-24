import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/storage_service.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        if (state.bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookmarks yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bookmark your favorite Gopher sites',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: state.bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = state.bookmarks[index];
            return _BookmarkItem(bookmark: bookmark);
          },
        );
      },
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;

  const _BookmarkItem({required this.bookmark});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bookmark),
      title: Text(bookmark.title),
      subtitle: Text(
        bookmark.url,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () => _confirmDelete(context),
      ),
      onTap: () {
        context.read<AppState>().navigate(bookmark.url);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bookmark'),
        content: Text('Remove "${bookmark.title}" from bookmarks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await context.read<AppState>().removeBookmark(bookmark.url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark removed')),
        );
      }
    }
  }
}
