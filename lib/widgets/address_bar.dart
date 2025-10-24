import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class AddressBar extends StatefulWidget {
  const AddressBar({super.key});

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Consumer<AppState>(
        builder: (context, state, child) {
          // Update text field when address changes from navigation
          if (state.currentAddress != null &&
              !_focusNode.hasFocus &&
              _controller.text != state.currentAddress!.toUrl()) {
            _controller.text = state.currentAddress!.toUrl();
          }

          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Enter gopher:// URL',
                    prefixIcon: const Icon(Icons.public),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      _navigate(context, value);
                    }
                  },
                  textInputAction: TextInputAction.go,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _controller.text.isNotEmpty
                    ? () => _navigate(context, _controller.text)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Go'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigate(BuildContext context, String url) {
    // Add scheme if missing
    if (!url.startsWith('gopher://')) {
      url = 'gopher://$url';
    }

    context.read<AppState>().navigate(url);
    _focusNode.unfocus();
  }
}
