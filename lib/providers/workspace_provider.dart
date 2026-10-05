import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/rag_service.dart';
import '../services/storage_service.dart';
import '../services/terminal_service.dart';
import '../services/workspace_service.dart';

class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceService workspaceService;
  final TerminalService terminalService;
  final RagService ragService;
  final StorageService storageService;

  String? _rootPath;
  List<FileItem> _fileTree = [];
  bool _isLoadingFiles = false;

  // Editor state
  String? _currentOpenFilePath;
  String _currentFileContent = '';
  bool _isFileDirty = false;
  bool _isSavingFile = false;

  // RAG state
  RagIndexStats _ragStats = RagIndexStats(
    totalFiles: 0,
    totalChunks: 0,
    lastIndexed: DateTime.now(),
  );

  // Terminal state
  final List<String> _terminalLogs = [];
  bool _isCommandRunning = false;

  StreamSubscription<RagIndexStats>? _ragSub;
  StreamSubscription<String>? _termSub;

  WorkspaceProvider({
    required this.workspaceService,
    required this.terminalService,
    required this.ragService,
    required this.storageService,
  }) {
    _initSubscriptions();
    _loadSavedWorkspace();
  }

  String? get rootPath => _rootPath;
  List<FileItem> get fileTree => _fileTree;
  bool get isLoadingFiles => _isLoadingFiles;

  String? get currentOpenFilePath => _currentOpenFilePath;
  String get currentFileContent => _currentFileContent;
  bool get isFileDirty => _isFileDirty;
  bool get isSavingFile => _isSavingFile;

  RagIndexStats get ragStats => _ragStats;
  List<String> get terminalLogs => List.unmodifiable(_terminalLogs);
  bool get isCommandRunning => _isCommandRunning;

  void _initSubscriptions() {
    _ragSub = ragService.statsStream.listen((stats) {
      _ragStats = stats;
      notifyListeners();
    });

    _termSub = terminalService.logStream.listen((line) {
      _terminalLogs.add(line);
      notifyListeners();
    });
  }

  void _loadSavedWorkspace() {
    final saved = storageService.getLastWorkspace();
    if (saved != null && Directory(saved).existsSync()) {
      setWorkspace(saved, startIndexing: true);
    }
  }

  Future<void> pickWorkspaceFolder() async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Workspace Folder for AI Agent',
      );
      if (selectedPath != null && selectedPath.isNotEmpty) {
        await setWorkspace(selectedPath, startIndexing: true);
      }
    } catch (e) {
      debugPrint('Error picking folder: $e');
    }
  }

  Future<void> setWorkspace(String path, {bool startIndexing = true}) async {
    _rootPath = path;
    workspaceService.setRoot(path);
    await storageService.setLastWorkspace(path);
    _currentOpenFilePath = null;
    _currentFileContent = '';
    _isFileDirty = false;

    await refreshFileTree();

    if (startIndexing) {
      final apiKey = storageService.getApiKey();
      unawaited(ragService.indexWorkspace(geminiApiKey: apiKey));
    }
    notifyListeners();
  }

  Future<void> refreshFileTree() async {
    if (_rootPath == null) return;
    _isLoadingFiles = true;
    notifyListeners();

    try {
      _fileTree = await workspaceService.loadDirectoryTree(_rootPath!);
    } catch (e) {
      debugPrint('Error loading directory tree: $e');
    } finally {
      _isLoadingFiles = false;
      notifyListeners();
    }
  }

  Future<void> openFile(String fullPath) async {
    try {
      final isDir = await FileSystemEntity.isDirectory(fullPath);
      if (isDir) return;

      final content = await workspaceService.readFile(fullPath);
      _currentOpenFilePath = fullPath;
      _currentFileContent = content;
      _isFileDirty = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reading file: $e');
    }
  }

  void updateEditorContent(String newContent) {
    if (newContent != _currentFileContent) {
      _currentFileContent = newContent;
      _isFileDirty = true;
      notifyListeners();
    }
  }

  Future<bool> saveCurrentFile() async {
    if (_currentOpenFilePath == null || !_isFileDirty) return false;
    _isSavingFile = true;
    notifyListeners();

    try {
      await workspaceService.writeFile(_currentOpenFilePath!, _currentFileContent);
      _isFileDirty = false;
      _isSavingFile = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSavingFile = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> createNewFile(String relativePath, {String content = ''}) async {
    if (_rootPath == null) return;
    await workspaceService.writeFile(relativePath, content);
    await refreshFileTree();
    final full = workspaceService.resolvePath(relativePath);
    await openFile(full);
  }

  Future<void> createNewFolder(String relativePath) async {
    if (_rootPath == null) return;
    final full = workspaceService.resolvePath(relativePath);
    await Directory(full).create(recursive: true);
    await refreshFileTree();
  }

  Future<void> deleteFileOrFolder(String targetPath) async {
    await workspaceService.deleteFile(targetPath);
    if (_currentOpenFilePath == targetPath) {
      _currentOpenFilePath = null;
      _currentFileContent = '';
      _isFileDirty = false;
    }
    await refreshFileTree();
  }

  Future<void> triggerRagReindex() async {
    if (_rootPath == null) return;
    final apiKey = storageService.getApiKey();
    await ragService.indexWorkspace(geminiApiKey: apiKey);
  }

  Future<TerminalCommandResult?> runManualTerminalCommand(String command) async {
    if (_rootPath == null || command.trim().isEmpty) return null;
    _isCommandRunning = true;
    notifyListeners();

    try {
      final res = await terminalService.execute(command, workingDirectory: _rootPath!);
      _isCommandRunning = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isCommandRunning = false;
      notifyListeners();
      return null;
    }
  }

  void clearTerminalLogs() {
    terminalService.clearLogs();
    _terminalLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ragSub?.cancel();
    _termSub?.cancel();
    super.dispose();
  }
}
