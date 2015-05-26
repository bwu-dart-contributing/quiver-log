library bwu_log.src.syslog_appender;

import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:bwu_log/bwu_log.dart' as log;
import 'package:bwu_log/bwu_log_io.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'dart:async' show Future;
import 'package:collection/wrappers.dart';

// const simpleSyslogFormatter = const SimpleSyslogFormatter();

typedef SyslogTransport SyslogTransportFactory([Map config]);

final Map<String, SyslogTransportFactory> _syslogTransportFactories =
    <String, SyslogTransportFactory>{
  'udp': ([Map config]) =>
      new SyslogUdpTransport(new SyslogUdpTransportConfig(config))
};

Map<String, SyslogTransportFactory> get syslogTransportFactories =>
    new UnmodifiableMapView(_syslogTransportFactories);

void registerSyslogTransportFactory(String name, SyslogTransportFactory factory,
    {override: false}) {
  final bool exists = _syslogTransportFactories[name] != null;
  if (exists && !override) {
    throw 'SyslogTransportFactory "${name}" is already registered. You can use "override: true" to force override.';
  }
  _syslogTransportFactories[name] = factory;
}

SyslogTransportFactory removeSyslogTransportFactory(String name) =>
    _syslogTransportFactories.remove(name);

class SyslogAppenderConfig extends log.AppenderConfig {
  static get defaultConfig =>
      {'formatter': defaultFormatter, 'transport': 'udp',};

  final Map _configuration;

  SyslogAppenderConfig([Map configuration])
      : _configuration = configuration != null ? configuration : defaultConfig {
    assert(_configuration != null);
  }

  static final defaultFormatter =
      new SimpleSyslogFormatter(new SimpleSyslogFormatterConfig());

  log.Formatter get formatter {
    final formatter = formatters[_configuration['formatter']];
    return formatter != null ? formatter : defaultFormatter;
  }

  static const defaultTransport = 'udp';

  SyslogTransport get transport {
    final transportName = _configuration['transport'];
    final transportConfig = _configuration['transport_config'];
    if (transportName != null) {
      final factory = _syslogTransportFactories[transportName];
      if (factory != null) {
        return factory(transportConfig);
      }
    }
    return _syslogTransportFactories[defaultTransport](
        _configuration['transport_config']);
  }
}

enum TransgressionAction { split, truncate, }

enum Protocol { tcp, udp, }

abstract class SyslogTransport {
  bool get isOpen;
  void open();
  void close();
  void send(List<int> data);
}

class SyslogUdpTransport implements SyslogTransport {
  bool get isOpen => _socket != null;
  SyslogUdpTransportConfig _config;
  io.RawDatagramSocket _socket;
  io.InternetAddress _host;

  SyslogUdpTransport([this._config]) {
    if (_config == null) _config = new SyslogUdpTransportConfig();
  }

  Future open() async {
    try {
      _host = await _config.host;
      _socket = await io.RawDatagramSocket.bind(
          await io.InternetAddress.ANY_IP_V4, 0);
    } catch (e) {
      // Prevent logging from crashing the app
      // TODO(zoechi) find some way to handle this properly
    }
  }

  Future close() async {
    _socket.close();
    await _socket.drain();
    _socket = null;
  }

  int send(List<int> data) {
    if (isOpen) {
      return _socket.send(data, _host, _config.port);
    }
    return 0;
  }
}

class SyslogUdpTransportConfig {
  static const Map defaultConfig = const {
    'host': 'localhost',
    'port': 514,
    'max_message_length': 2048,
    'transgression_action': 'split',
  };

  Map _configuration;
  SyslogUdpTransportConfig([this._configuration]) {
    if (_configuration == null) {
      _configuration = defaultConfig;
    }
  }

  static const defaultMaxMessageLength = 2048;

  int get maxMessageLength {
    final max = _configuration['max_message_length'];
    try {
      return max != null ? int.parse(max) : defaultMaxMessageLength;
    } catch (_) {
      print('SyslogAppenderConfig: Unsupported max_message_length "${max}".');
    }
  }

  static const defaultTransgressionAction = TransgressionAction.split;

  TransgressionAction get transgressionAction {
    final String action = _configuration['transgression_action'];
    if (action == null) {
      return defaultTransgressionAction;
    }
    switch (action) {
      case 'split':
        return TransgressionAction.split;
      case 'truncate':
        return TransgressionAction.truncate;
      default:
        print(
            'SyslogAppenderConfig: Unsupported transgression_action "${action}".');
        return defaultTransgressionAction;
    }
  }

  static const defaultProtocol = Protocol.tcp;

//  Protocol get protocol {
//    final String proto = _configuration['protocol'];
//    if (proto == null) {
//      return defaultProtocol;
//    }
//    switch (proto) {
//      case 'tcp':
//        return Protocol.tcp;
//      case 'udp':
//        return Protocol.udp;
//      default:
//        print('SyslogAppenderConfig: Unsupported protocol "${proto}".');
//        return defaultProtocol;
//    }
//  }

  // TODO(zoechi) find out why it doesn't work with io.InternetAddress.LOOPBACK_IP_V6
  static final defaultHost = io.InternetAddress.LOOPBACK_IP_V4;

  Future<io.InternetAddress> get host async {
    final String host = _configuration['_host'];
    if (host != null) {
      try {
        return new io.InternetAddress(host);
      } catch (_) {}
      try {
        return (await io.InternetAddress.lookup(host)).first;
      } catch (_) {}
    }
    return defaultHost;
  }

  static const defaultPort = 514;

  int get port {
    final p = _configuration['port'];
    if (p == null) {
      return defaultPort;
    } else if (p is! int) {
      print('SyslogAppenderConfig: Port "${p}" is not a valid integer value');
    }

    return p;
  }
}

class SyslogAppender extends log.Appender<SyslogMessage> {
  SyslogTransport _transport;
  SyslogAppenderConfig get configuration => super.configuration;

  SyslogAppender(SyslogAppenderConfig config) : super(config) {
    _transport = config.transport;
  }

  static final DateFormat _dateFormat = new DateFormat("MMM dd hh:mm:ss");

  void append(LogRecord record, log.Formatter<SyslogMessage> formatter) {
    final SyslogMessage msg = formatter(record);
    if (msg.message.isNotEmpty) {
      io.BytesBuilder header = new io.BytesBuilder();

      _addHeader(header, msg);

      if (msg.tag != null) {
        header.add(msg.tag.substring(0, math.min(
            31 - msg.messageId.toString().length, msg.tag.length)).codeUnits);
      }
      header.add('-'.codeUnits);
      header.add(msg.messageId.toString().codeUnits);
      header.add(':'.codeUnits);

      int pos = 0;
      final maxPartLen = maxMessageLength - header.length;

      while (pos < msg.message.length) {
        io.BytesBuilder message = new io.BytesBuilder();
        message.add(header.toBytes());

        final len = math.min(msg.message.length - pos, maxPartLen);
        final msgPart = msg.message.substring(pos, len);
        pos += len;
        message.add(msgPart.codeUnits);
        _send(new Uint8List.fromList(message.toBytes()));
        //_send(new Uint8List.fromList('<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - BOM\'su root\' failed for lonvick on /dev/pts/8'.codeUnits));

      }
    }
  }

  final _space = ' '.codeUnits;
  void _addHeader(io.BytesBuilder header, SyslogMessage msg) {
    _addPri(header, msg.facility, msg.severity);
    _addVersion(header);
    header.add(_space);
    _addTimeStamp(header, msg.timeStamp);
    header.add(_space);
    _addHostname(header, msg.hostname);
    header.add(_space);
    _addAppName(header, msg.appName);
    header.add(_space);
  }

  void _addPri(io.BytesBuilder header, Facility facility, Severity severity) {
    header.add('<'.codeUnits);
    header.add(((facility.index << 3) + severity.index).toString().codeUnits);
    header.add('>'.codeUnits);
  }

  void _addTimeStamp(io.BytesBuilder header, DateTime timeStamp) {
    // RFC 5424
    header.add(timeStamp.toUtc().toIso8601String().codeUnits);

    // RFC 3164
//    String ts = _dateFormat.format(timeStamp);
//    if (ts[4] == '0') {
//      ts = ts.replaceRange(4, 5, ' ');
//    }
//    header.add(ts.codeUnits);
//    header.add(' '.codeUnits);
  }

  void _addVersion(io.BytesBuilder header) {
    header.add('1'.codeUnits);
  }

  void _addHostname(io.BytesBuilder header, String hostname) {
    /// if FQN is provided extract the hostname
    if (hostname != null) {
      header.add(hostname.split('.').first.codeUnits);
    }
    header.add(' '.codeUnits);
  }

  void _addAppName(io.BytesBuilder header, String appName) {}

  Future<Null> _send(List<int> bytes) async {
    if (!_transport.isOpen) {
      await _transport.open();
    }
    // print(new String.fromCharCodes(bytes));
    _transport.send(bytes);
  }
}

enum Severity {
  emergency,
  alert,
  critical, // shout
  error, // severe
  warning, // warning
  notice, // info
  informational, // config
  debug, // fine
}

enum Facility {
  /// 0 - kernel messages
  kern,
  /// 1 - user-level messages
  user,
  /// 2 - mail system
  mail,
  /// 3 - system daemons
  daemon,
  /// 4 - security/authorization messages
  auth,
  /// 5 - messages generated internally by syslogd
  syslog,
  /// 6 - line printer subsystem
  lpr,
  /// 7 - network news subsystem
  news,
  /// 8 - UUCP subsystem
  uucp,
  /// 9 - clock daemon
  clock,
  /// 10 - security/authorization messages
  authpriv,
  /// 11 - FTP daemon
  ftp,
  /// 12 - NTP subsystem
  ntp,
  /// 13 - log audit
  logAudit,
  /// 14 - log alert
  logAlert,
  /// 15 - clock daemon (note 2)
  cron,
  /// 16 - local use 0 (local0)
  local0,
  /// 17 - local use 0 (local1)
  local1,
  /// 18 - local use 0 (local2)
  local2,
  /// 19 - local use 0 (local3)
  local3,
  /// 20 - local use 0 (local4)
  local4,
  /// 21 - local use 0 (local5)
  local5,
  /// 22 - local use 0 (local6)
  local6,
  /// 23 - local use 0 (local7)
  local7,
}

class SyslogMessage {
  // RFC 3164
  // 0 - Emergency: system is unusable
  final Severity severity;
  // 1 - Alert: action must be taken immediately
  final Facility facility;
  // 2 - Critical: critical conditions
  final DateTime timeStamp;
  // 3 - Error: error conditions
  final String hostname;
  // 4 - Warning: warning conditions
  final String tag;
  // 5 - Notice: normal but significant condition
  //final int sequenceNumber;
  // renamed by RFC 5424
  final int messageId;
  // 6 - Informational: informational messages
  final String message;

  // added by RFC 5424
  final String appName;
  final String processId;

  const SyslogMessage(this.severity, this.facility, this.timeStamp,
      this.hostname, this.tag, this.messageId, this.message,
      [this.appName, this.processId]);
}

const int maxMessageLength = 1024;
const String splitter = '\n>>>\n';

class SimpleSyslogFormatter extends log.FormatterBase<SyslogMessage> {
  final SimpleSyslogFormatterConfig _configuration;

  SimpleSyslogFormatter(this._configuration) : super();

  SyslogMessage call(LogRecord record) {
    Severity severity;
    if (record.level.value >= 1600) {
      severity = Severity.emergency;
    } else if (record.level.value >= 1400) {
      severity = Severity.alert;
    } else if (record.level.value >= Level.SHOUT.value) {
      severity = Severity.critical;
    } else if (record.level.value >= Level.SEVERE.value) {
      severity = Severity.error;
    } else if (record.level.value >= Level.WARNING.value) {
      severity = Severity.warning;
    } else if (record.level.value >= Level.INFO.value) {
      severity = Severity.notice;
    } else if (record.level.value >= Level.CONFIG.value) {
      severity = Severity.informational;
    } else if (record.level.value >= Level.FINE.value) {
      severity = Severity.debug;
    }
    String message = record.message;
    if (message == null) {
      message = '';
    }
    if (record.error != null) {
      message = '${message}${splitter}${record.error}';
    }
    if (record.stackTrace != null) {
      message = '${message}${splitter}${record.stackTrace}';
    }

    String tag = record.loggerName;

    return new SyslogMessage(severity, Facility.user, record.time,
        io.Platform.localHostname, tag, record.sequenceNumber, message, null,
        record.zone['LOGGING_ZONE_NAME']);
  }
}

class SimpleSyslogFormatterConfig implements log.FormatterConfig {
  static const Map defaultConfig = const {'app_name': ''};
  Map _configuration;

  String get appName => _configuration['app_name'];

  SimpleSyslogFormatterConfig([this._configuration]) {
    if (_configuration == null) {
      _configuration = defaultConfig;
    }
  }
}
