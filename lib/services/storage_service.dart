import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gopher_item.dart';

/// Bookmark data model
class Bookmark {
  final String title;
  final String url;
  final DateTime created;

  Bookmark({
    required this.title,
    required this.url,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'created': created.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        title: json['title'] as String,
        url: json['url'] as String,
        created: DateTime.parse(json['created'] as String),
      );
}

/// History entry data model
class HistoryEntry {
  final String url;
  final String title;
  final DateTime timestamp;

  HistoryEntry({
    required this.url,
    required this.title,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        url: json['url'] as String,
        title: json['title'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Service for managing bookmarks and history
class StorageService {
  static const String _bookmarksKey = 'bookmarks';
  static const String _historyKey = 'history';
  static const int _maxHistoryItems = 100;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Bookmarks management

  Future<List<Bookmark>> getBookmarks() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_bookmarksKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Bookmark.fromJson(json)).toList();
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();

    // Avoid duplicates
    if (bookmarks.any((b) => b.url == bookmark.url)) {
      return;
    }

    bookmarks.add(bookmark);
    await _saveBookmarks(bookmarks);
  }

  Future<void> removeBookmark(String url) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.url == url);
    await _saveBookmarks(bookmarks);
  }

  Future<bool> isBookmarked(String url) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b.url == url);
  }

  Future<void> _saveBookmarks(List<Bookmark> bookmarks) async {
    await _ensureInitialized();
    final jsonString = json.encode(bookmarks.map((b) => b.toJson()).toList());
    await _prefs!.setString(_bookmarksKey, jsonString);
  }

  // History management

  Future<List<HistoryEntry>> getHistory() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString(_historyKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => HistoryEntry.fromJson(json)).toList();
  }

  Future<void> addToHistory(HistoryEntry entry) async {
    final history = await getHistory();

    // Remove existing entry with same URL to avoid duplicates
    history.removeWhere((h) => h.url == entry.url);

    // Add new entry at the beginning
    history.insert(0, entry);

    // Limit history size
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await _saveHistory(history);
  }

  Future<void> clearHistory() async {
    await _ensureInitialized();
    await _prefs!.remove(_historyKey);
  }

  Future<void> _saveHistory(List<HistoryEntry> history) async {
    await _ensureInitialized();
    final jsonString = json.encode(history.map((h) => h.toJson()).toList());
    await _prefs!.setString(_historyKey, jsonString);
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }
}
