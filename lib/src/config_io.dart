library bwu_log.src.config_io;

import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:bwu_log/bwu_log.dart' as log;
import 'package:yaml/yaml.dart';
import 'package:bwu_log/src/syslog_appender.dart';
import 'package:collection/wrappers.dart';

final Map<String, log.FormatterFactory> _formatterFactories =
    <String, log.FormatterFactory>{
  'Default': ([SimpleSyslogFormatterConfig config]) =>
      new SimpleSyslogFormatter(config),
  'Simple': ([SimpleSyslogFormatterConfig config]) =>
      new SimpleSyslogFormatter(config),
}..addAll(log.formatters);

Map<String, log.Formatter> get formatters =>
    new UnmodifiableMapView(_formatterFactories);

void registerFormatter(String name, log.FormatterFactory factory,
    {override: false}) {
  final bool exists = _formatterFactories[name] != null;
  if (exists && !override) {
    throw 'Formatter "${name}" is already registers. You can use "override: true" to force override.';
  }
  _formatterFactories[name] = factory;
}

log.FormatterFactory removeFormatter(String name) =>
    _formatterFactories.remove(name);

final Map<String, log.AppenderFactory> _appenderFactories =
    <String, log.AppenderFactory>{
  'Syslog':
      ([Map config]) => new SyslogAppender(new SyslogAppenderConfig(config)),
}..addAll(log.appenderFactories);

Map<String, log.AppenderFactory> get appenderFactories =>
    new UnmodifiableMapView(_appenderFactories);

void registerAppenderFactory(String name, log.AppenderFactory factory,
    {override: false}) {
  final bool exists = _appenderFactories[name] != null;
  if (exists && !override) {
    throw 'Formatter "${name}" is already registers. You can use "override: true" to force override.';
  }
  _appenderFactories[name] = factory;
}

log.AppenderFactory removeAppenderFactory(String name) =>
    _appenderFactories.remove(name);

IoConfig _logConfig;
IoConfig get logConfig {
  if (_logConfig == null) {
    _logConfig = new IoConfig._();
  }
  return _logConfig;
}

class IoConfig extends log.LogConfig {
  static final _ioFormatters = {
    'SimpleSyslog': SyslogAppenderConfig.defaultFormatter
  };

  static final _ioAppenderFactories = {
    'Syslog':
        ([Map config]) => new SyslogAppender(new SyslogAppenderConfig(config)),
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
