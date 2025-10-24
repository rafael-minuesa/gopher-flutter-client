import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gopher_item.dart';
import '../services/app_state.dart';

class MenuView extends StatelessWidget {
  final List<GopherItem> items;

  const MenuView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MenuItemTile(item: item);
      },
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final GopherItem item;

  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    // Info items are not clickable
    if (item.type == GopherItemType.info) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        child: Text(
          item.displayText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Error items
    if (item.type == GopherItemType.error) {
      return ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text(
          item.displayText,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // Navigable items
    return ListTile(
      leading: _getIcon(item.type),
      title: Text(item.displayText),
      subtitle: item.type == GopherItemType.directory ||
              item.type == GopherItemType.file
          ? Text(
              '${item.host}:${item.port}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: item.type.isNavigable ? const Icon(Icons.chevron_right) : null,
      onTap: item.type.isNavigable
          ? () {
              if (item.type == GopherItemType.search) {
                _showSearchDialog(context, item);
              } else {
                context.read<AppState>().navigateToItem(item);
              }
            }
          : null,
    );
  }

  Widget _getIcon(GopherItemType type) {
    IconData iconData;
    Color? color;

    switch (type) {
      case GopherItemType.directory:
        iconData = Icons.folder;
        color = Colors.blue;
        break;
      case GopherItemType.file:
        iconData = Icons.description;
        color = Colors.grey;
        break;
      case GopherItemType.search:
        iconData = Icons.search;
        color = Colors.green;
        break;
      case GopherItemType.gif:
      case GopherItemType.image:
        iconData = Icons.image;
        color = Colors.purple;
        break;
      case GopherItemType.binary:
      case GopherItemType.binhex:
      case GopherItemType.dos:
        iconData = Icons.file_download;
        color = Colors.orange;
        break;
      case GopherItemType.html:
        iconData = Icons.language;
        color = Colors.teal;
        break;
      case GopherItemType.error:
        iconData = Icons.error;
        color = Colors.red;
        break;
      case GopherItemType.info:
        iconData = Icons.info;
        color = Colors.grey;
        break;
      case GopherItemType.telnet:
      case GopherItemType.tn3270:
        iconData = Icons.terminal;
        color = Colors.cyan;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }

  Future<void> _showSearchDialog(BuildContext context, GopherItem item) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.displayText),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search query',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      // TODO: Implement search functionality
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for: $result')),
      );
    }
  }

  bool get isNavigable => item.type.isNavigable;
}
