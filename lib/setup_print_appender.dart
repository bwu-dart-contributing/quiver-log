library bwu_log.setup_print_appender;

import 'package:bwu_log/bwu_log.dart' show basicLogFormatter, PrintAppender;
import 'package:logging/logging.dart'
    show hierarchicalLoggingEnabled, Logger, Level;

export 'package:logging/logging.dart' show Logger, Level;

void initLogging([Level loggingLevel]) {
  hierarchicalLoggingEnabled = true;

  Logger.root.level = loggingLevel ?? Level.SEVERE;

  final PrintAppender appender = new PrintAppender(basicLogFormatter);
  appender.attachLogger(Logger.root);
}
