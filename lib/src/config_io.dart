library bwu_log.src.config_io;

import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:bwu_log/bwu_log.dart' as log;
import 'package:yaml/yaml.dart';
import 'package:bwu_log/src/syslog_appender.dart';

IoConfig _logConfig;
IoConfig get logConfig {
  if (_logConfig == null) {
    _logConfig = new IoConfig._();
  }
  return _logConfig;
}

class IoConfig extends log.DefaultConfig {
  static const _ioFormatters = const {'SimpleSyslog': SIMPLE_SYSLOG_FORMATTER};

  static final _ioAppenderFactories = {
    'Syslog': (log.Formatter formatter) => new SyslogAppender(formatter),
  };

  IoConfig._() : super.protected() {
    _ioFormatters.keys
        .forEach((k) => log.registerFormatter(k, _ioFormatters[k]));
    _ioAppenderFactories.keys.forEach(
        (k) => log.registerAppenderFactory(k, _ioAppenderFactories[k]));
  }

  void loadConfig([String configFilePath]) {
    String filePath;
    if (configFilePath != null) {
      filePath = configFilePath;
    } else {
      filePath = findConfigFile();
    }
    var fileContent = new io.File(filePath).readAsStringSync();
    init(config: loadYaml(fileContent));
  }

  static String findConfigFile() {
    String findUpwards(String startDirectory) {
      String currentDirectory = startDirectory;
      if (currentDirectory != null) {
        while (currentDirectory.isNotEmpty) {
          final filePath =
              path.join(currentDirectory, 'bwu_log.yaml').toString();
          if (new io.File(filePath).existsSync()) {
            return filePath;
          }
          currentDirectory =
              new io.Directory(currentDirectory).parent.toString();
        }
      }
      return null;
    }
    String configFile = findUpwards(path.current);
    if (configFile != null) {
      return configFile;
    }
    return findUpwards(path.dirname(io.Platform.executable));
  }

  static final envRegExp = new RegExp(r'\${(.+)}');
  String resolveEnvironment(String name) {
    return name.splitMapJoin(envRegExp, onMatch: (Match m) {
      final val = io.Platform.environment[m.group(1)];
      if (val == null) {
        return m.group(0);
      }
      return io.Platform.environment[m.group(1)];
    });
  }

  @override
  String get activeConfigName => resolveEnvironment(super.activeConfigName);
}
