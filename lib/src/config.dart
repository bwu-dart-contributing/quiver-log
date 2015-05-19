part of bwu_log;

typedef Appender AppenderFactory([Map config]);

final Map<String, Formatter> _formatters = <String, Formatter>{
  'Default': const BasicLogFormatter(),
  'Basic': const BasicLogFormatter(),
};

Map<String, Formatter> get formatters => new UnmodifiableMapView(_formatters);

void registerFormatter(String name, Formatter factory, {override: false}) {
  final bool exists = _formatters[name] != null;
  if (exists && !override) {
    throw 'Formatter "${name}" is already registers. You can use "override: true" to force override.';
  }
  _formatters[name] = factory;
}

Formatter removeFormatter(String name) => _formatters.remove(name);

final Map<String, AppenderFactory> _appenderFactories =
    <String, AppenderFactory>{
  'Default': ([Map config]) => new PrintAppender(new PrintAppenderConfig(config)),
  'Print': ([Map config]) => new PrintAppender(new PrintAppenderConfig(config)),
  'InMemoryList': ([Map config]) => new PrintAppender(new PrintAppenderConfig(config)),
};

Map<String, AppenderFactory> get appenderFactories =>
    new UnmodifiableMapView(_appenderFactories);

void registerAppenderFactory(String name, AppenderFactory factory,
    {override: false}) {
  final bool exists = _appenderFactories[name] != null;
  if (exists && !override) {
    throw 'Formatter "${name}" is already registers. You can use "override: true" to force override.';
  }
  _appenderFactories[name] = factory;
}

AppenderFactory removeAppenderFactory(String name) =>
    _appenderFactories.remove(name);

LogConfig _logConfig;
LogConfig get logConfig {
  if (_logConfig == null) {
    _logConfig = new LogConfig._();
  }
  return _logConfig;
}
set logConfig(LogConfig config) => _logConfig = config;

abstract class Config {
  Appender get appender;
  String get activeConfigName;
}

/// Helper to process the logger configuration.
class LogConfig {
  final Map config = {};
  String _activeConfigName = 'default';
  String get activeConfigName =>
      _activeConfigName != null ? _activeConfigName : 'default';
  set activeConfigName(String name) => _activeConfigName = name;

  LogConfig._();

  LogConfig.protected();

  void init({Map config, String configName}) {
    if (config != null) {
      this.config.addAll(config);
    }
    if (configName != null) {
      activeConfigName = configName;
    } else {
      activeConfigName = config['active'];
    }
  }

  Map get configurations =>
      config['configurations'] == null ? {} : config['configurations'];

  Map get defaultConfiguration {
    final c = configurations['default'];
    return c != null ? c : {'appender': 'print', 'formatter': 'basic'};
  }

  Map get activeConfiguration {
    if (configurations == null || configurations[activeConfigName] == null) {
      return defaultConfiguration;
    }
    return configurations[activeConfigName];
  }

//  Formatter get formatter => formatters[activeConfiguration['formatter']];
  Map get appenderConfiguration => activeConfiguration['appender_config'];

  Appender get appender =>
      appenderFactories[activeConfiguration['appender']](appenderConfiguration);


}

abstract class AppenderConfig {
  Formatter formatter;
}
