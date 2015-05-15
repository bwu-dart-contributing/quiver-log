import 'package:bwu_log/log.dart';
import 'package:bwu_log/web.dart';
import 'package:logging/logging.dart';


main() {
  Logger _logger = new Logger('testlogger');
  Appender _logAppender = new WebAppender.webConsole(BASIC_LOG_FORMATTER);
  Logger.root.level = Level.ALL;
  _logAppender.attachLogger(_logger);

  _logger.finest('finest message');
  _logger.finer('finer message');
  _logger.fine('fine message');
  _logger.config('config message');
  _logger.info('info message');
  _logger.warning('warning message');
  _logger.severe('severe message');
  _logger.shout('severe message');

}
