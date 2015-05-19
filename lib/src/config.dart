part of bwu_log;

typedef Appender AppenderFactory(Formatter formatter);

final Map<String, Formatter> _formatters = <String, Formatter>{
  'Default': BASIC_LOG_FORMATTER,
  'Basic': BASIC_LOG_FORMATTER,
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
  'Default': (Formatter formatter) => new PrintAppender(formatter),
  'Print': (Formatter formatter) => new PrintAppender(formatter),
  'InMemoryList': (Formatter formatter) => new PrintAppender(formatter),
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

Config _logConfig;
Config get logConfig {
  if (_logConfig == null) {
    _logConfig = new DefaultConfig._();
  }
  return _logConfig;
}
set logConfig(Config config) => _logConfig = config;

abstract class Config {
  Appender get appender;
  String get activeConfigName;
}

class DefaultConfig implements Config {
  final Map config = {};
  String _activeConfigName = 'default';
  String get activeConfigName => _activeConfigName != null ? _activeConfigName : 'default';
  set activeConfigName(String name) => _activeConfigName = name;

  DefaultConfig._();

  DefaultConfig.protected();

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

  Formatter get formatter => formatters[activeConfiguration['formatter']];

  Appender get appender =>
      appenderFactories[activeConfiguration['appender']](formatter);
}

abstract class AppenderConfig {
}
