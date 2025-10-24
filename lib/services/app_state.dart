import 'package:flutter/foundation.dart';
import '../models/gopher_item.dart';
import 'gopher_client.dart';
import 'storage_service.dart';

/// Application state manager
class AppState extends ChangeNotifier {
  final GopherClient _client = GopherClient();
  final StorageService _storage = StorageService();

  // Navigation state
  GopherAddress? _currentAddress;
  List<GopherItem>? _currentMenu;
  String? _currentContent;
  bool _isLoading = false;
  String? _error;

  // Navigation history (for back/forward buttons)
  final List<GopherAddress> _navigationHistory = [];
  int _navigationIndex = -1;

  // Bookmarks
  List<Bookmark> _bookmarks = [];

  // History
  List<HistoryEntry> _history = [];

  // Getters
  GopherAddress? get currentAddress => _currentAddress;
  List<GopherItem>? get currentMenu => _currentMenu;
  String? get currentContent => _currentContent;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canGoBack => _navigationIndex > 0;
  bool get canGoForward =>
      _navigationIndex < _navigationHistory.length - 1;
  List<Bookmark> get bookmarks => _bookmarks;
  List<HistoryEntry> get history => _history;

  Future<void> init() async {
    await _storage.init();
    await loadBookmarks();
    await loadHistory();
  }

  /// Navigate to a Gopher address
  Future<void> navigate(String url) async {
    try {
      final address = GopherAddress.fromUrl(url);
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Fetch content
      final items = await _client.fetchMenu(address);

      // Update navigation history
      if (_navigationIndex < _navigationHistory.length - 1) {
        _navigationHistory.removeRange(
          _navigationIndex + 1,
          _navigationHistory.length,
        );
      }
      _navigationHistory.add(address);
      _navigationIndex = _navigationHistory.length - 1;

      // Update state
      _currentAddress = address;
      _currentMenu = items;
      _currentContent = null;
      _isLoading = false;

      // Add to history
      await _storage.addToHistory(HistoryEntry(
        url: url,
        title: url,
      ));
      await loadHistory();

      notifyListeners();
    } on GopherException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Unexpected error: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Navigate to a Gopher item
  Future<void> navigateToItem(GopherItem item) async {
    if (item.type == GopherItemType.directory) {
      await navigate(item.toUrl());
    } else if (item.type == GopherItemType.file) {
      await viewFile(item);
    } else if (item.type == GopherItemType.search) {
      // For search items, we'll need to show a search dialog
      // For now, just navigate to the item
      await navigate(item.toUrl());
    }
  }

  /// View a text file
  Future<void> viewFile(GopherItem item) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final address = GopherAddress(
        host: item.host,
        port: item.port,
        selector: item.selector,
      );

      final content = await _client.fetch(address);

      _currentAddress = address;
      _currentContent = content;
      _currentMenu = null;
      _isLoading = false;

      // Add to history
      await _storage.addToHistory(HistoryEntry(
        url: item.toUrl(),
        title: item.displayText,
      ));
      await loadHistory();

      notifyListeners();
    } on GopherException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Unexpected error: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Go back in navigation history
  void goBack() {
    if (!canGoBack) return;
    _navigationIndex--;
    _loadFromHistory();
  }

  /// Go forward in navigation history
  void goForward() {
    if (!canGoForward) return;
    _navigationIndex++;
    _loadFromHistory();
  }

  Future<void> _loadFromHistory() async {
    final address = _navigationHistory[_navigationIndex];
    navigate(address.toUrl());
  }

  // Bookmarks management

  Future<void> loadBookmarks() async {
    _bookmarks = await _storage.getBookmarks();
    notifyListeners();
  }

  Future<void> addBookmark(String title, String url) async {
    await _storage.addBookmark(Bookmark(title: title, url: url));
    await loadBookmarks();
  }

  Future<void> removeBookmark(String url) async {
    await _storage.removeBookmark(url);
    await loadBookmarks();
  }

  Future<bool> isBookmarked(String url) async {
    return await _storage.isBookmarked(url);
  }

  // History management

  Future<void> loadHistory() async {
    _history = await _storage.getHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _storage.clearHistory();
    await loadHistory();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
