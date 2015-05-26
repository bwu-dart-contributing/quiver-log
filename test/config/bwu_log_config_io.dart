library bwu_log.test.config.bwu_log_config;

import 'dart:io' as io;
import 'package:logging/logging.dart';
import 'package:bwu_log/bwu_log.dart';
import 'package:bwu_log/src/syslog_appender.dart';

const logConfigEnvVar = 'BWU_LOG_CONFIG';

initLogging([String envVar = logConfigEnvVar]) {
  switch (configNameFromEnvironment(envVar)) {
    case 'development':
      final appender = new SyslogAppender(
          formatter: new SimpleSyslogFormatter(),
          transport: new SyslogUdpTransport(),
          filter: const BasicFilter(
              excludes: const [const FilterRule(loggerNamePattern: '.')],
              includes: const [
        const FilterRule(levels: const [Level.SHOUT, Level.SEVERE])
      ]));
      appender.attachLogger(Logger.root);
      break;

    case 'production':
      final appender = new SyslogAppender(
          formatter: new SimpleSyslogFormatter(),
          transport: new SyslogUdpTransport());
      appender.attachLogger(Logger.root);
      Logger.root.level = Level.ALL;
      break;

    case 'disabled':
      break;

    //case 'default':
    default:
      final appender = new PrintAppender(BASIC_LOG_FORMATTER);
      appender.attachLogger(Logger.root);
      // Logger.root.level = Level.INFO;
      break;
  }

  hierarchicalLoggingEnabled = true;
}

String configNameFromEnvironment(String envVar) {
  var config = new String.fromEnvironment(envVar);
  if (config != null && config.isNotEmpty) return config.toLowerCase();

  config = io.Platform.environment[envVar];
  if (config != null && config.isNotEmpty) return config.toLowerCase();

  return 'default';
}
