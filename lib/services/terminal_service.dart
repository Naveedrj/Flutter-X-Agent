import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TerminalCommandResult {
  final String command;
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration duration;

  TerminalCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.duration,
  });

  bool get isSuccess => exitCode == 0;

  String get outputCombined {
    final buffer = StringBuffer();
    if (stdout.trim().isNotEmpty) {
      buffer.writeln(stdout.trim());
    }
    if (stderr.trim().isNotEmpty) {
      buffer.writeln('[STDERR]\n${stderr.trim()}');
    }
    buffer.writeln('[Process exited with code $exitCode in ${duration.inMilliseconds}ms]');
    return buffer.toString();
  }
}

class TerminalService {
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final List<String> _historyLogs = [];
  List<String> get historyLogs => List.unmodifiable(_historyLogs);

  void appendLog(String line) {
    _historyLogs.add(line);
    _logController.add(line);
  }

  void clearLogs() {
    _historyLogs.clear();
    _logController.add('--- Terminal Logs Cleared ---');
  }

  Future<TerminalCommandResult> execute(
    String command, {
    required String workingDirectory,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final stopwatch = Stopwatch()..start();
    appendLog('\$ $command (in $workingDirectory)');

    String shell;
    List<String> args;

    if (Platform.isWindows) {
      shell = 'cmd.exe';
      args = ['/c', command];
    } else {
      // macOS or Linux
      shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      if (!File(shell).existsSync()) {
        shell = '/bin/bash';
      }
      args = ['-c', command];
    }

    try {
      final process = await Process.start(
        shell,
        args,
        workingDirectory: workingDirectory,
        environment: Platform.environment,
        runInShell: true,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .listen((data) {
        stdoutBuffer.write(data);
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) appendLog(line);
        }
      });

      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .listen((data) {
        stderrBuffer.write(data);
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) appendLog('[ERR] $line');
        }
      });

      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          appendLog('[TIMEOUT] Process was terminated after ${timeout.inSeconds}s');
          return -1;
        },
      );

      await stdoutSub.cancel();
      await stderrSub.cancel();
      stopwatch.stop();

      appendLog('[Exit $exitCode] (${stopwatch.elapsedMilliseconds}ms)');

      return TerminalCommandResult(
        command: command,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        exitCode: exitCode,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      final err = 'Failed to execute command: $e';
      appendLog('[ERROR] $err');
      return TerminalCommandResult(
        command: command,
        stdout: '',
        stderr: err,
        exitCode: -1,
        duration: stopwatch.elapsed,
      );
    }
  }

  void dispose() {
    _logController.close();
  }
}
