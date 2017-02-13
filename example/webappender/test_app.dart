import 'package:bwu_log/bwu_log.dart';
import 'package:bwu_log/web.dart';
import 'package:logging/logging.dart';

void main() {
  final _logger = new Logger('testlogger');
  final _logAppender = new WebAppender.webConsole(const BasicLogFormatter());
  Logger.root.level = Level.ALL;
  _logAppender.attachLogger(_logger);

  _logger
    ..finest('finest message')
    ..finer('finer message')
    ..fine('fine message')
    ..config('config message')
    ..info('info message')
    ..warning('warning message')
    ..severe('severe message')
    ..shout('severe message');
}
