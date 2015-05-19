library bwu_log.src.syslog_appender;

import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:bwu_log/bwu_log.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'dart:async' show Future;

const SIMPLE_SYSLOG_FORMATTER = const SimpleSyslogFormatter();

class SyslogAppenderConfig extends AppenderConfig {
  static get defaultConfig => {
    'formatter': defaultFormatter,
    'max_message_length': defaultMaxMessageLength,
    'transgression_action': defaultTransgressionAction,
    'protocol': defaultProtocol,
    'host': defaultHost,
    'port': defaultPort
  };

  final Map _configuration;
  SyslogAppenderConfig([Map configuration]) : _configuration = configuration != null ? configuration : defaultConfig {
    assert(_configuration != null);
  }

  static const defaultFormatter = const SimpleSyslogFormatter();
  Formatter get formatter {
    final formatter = _configuration['formatter'];
    return formatter != null ? formatter : defaultFormatter;
  }

  static const defaultMaxMessageLength = 2048;
  int get maxMessageLength {
    final max = _configuration['max_message_length'];
    try {
    return max != null ? int.parse(max) : defaultMaxMessageLength;
    } catch(_) {
      print('SyslogAppenderConfig: Unsupported max_message_length "${max}".');
    }
  }

  static const defaultTransgressionAction = TransgressionAction.split;
  TransgressionAction get transgressionAction {
    final String action = _configuration['transgression_action'];
    if(action == null) {
      return defaultTransgressionAction;
    }
    switch(action) {
      case 'split':
        return TransgressionAction.split;
      case 'truncate':
        return TransgressionAction.truncate;
      default:
        print('SyslogAppenderConfig: Unsupported transgression_action "${action}".');
        return defaultTransgressionAction;
    }
  }

  static const defaultProtocol = Protocol.tcp;
  Protocol get protocol {
    final String proto = _configuration['protocol'];
    if(proto == null) {
      return defaultProtocol;
    }
    switch(proto) {
      case 'tcp':
        return Protocol.tcp;
      case 'udp':
        return Protocol.udp;
      default:
        print('SyslogAppenderConfig: Unsupported protocol "${proto}".');
        return defaultProtocol;
    }
  }

  // TODO(zoechi) find out why it doesn't work with io.InternetAddress.LOOPBACK_IP_V6
  static final defaultHost = io.InternetAddress.LOOPBACK_IP_V4;
  Future<io.InternetAddress> get host async {
    final String host = _configuration['_host'];
    if(host != null) {
      try {
        return new io.InternetAddress(host);
      } catch(_) {}
      try {
        return (await io.InternetAddress.lookup(host)).first;
      } catch(_) {}
    }
    return defaultHost;
  }

  static const defaultPort = 514;
  int get port {
    final p = _configuration['port'];
    if(p == null) {
      return defaultPort;
    } else if (p is! int) {
      print('SyslogAppenderConfig: Port "${p}" is not a valid integer value');
    }

    return p;
  }
}

enum TransgressionAction {
  split,
  truncate,
}

enum Protocol {
  tcp,
  udp,
}

class SyslogAppender extends Appender<SyslogMessage> {

  io.RawDatagramSocket _socket;
  SyslogAppenderConfig _config;
  factory SyslogAppender(Formatter<SyslogMessage> formatter) {
    final config = new Map.from(SyslogAppenderConfig.defaultConfig);
    if(formatter != null) {
      config['formatter'] = formatter;
    }
    return new SyslogAppender._fromConfig(new SyslogAppenderConfig(config), config['formatter']);
  }

  factory SyslogAppender.fromConfig(SyslogAppenderConfig config) {
    if(config == null) {
      config = SyslogAppenderConfig.defaultConfig;
    }
    return new SyslogAppender._fromConfig(config, config.formatter);
  }

  SyslogAppender._fromConfig(this._config, Formatter formatter) : super(formatter);

  static final DateFormat _dateFormat = new DateFormat("MMM dd hh:mm:ss");

  void append(LogRecord record, Formatter<SyslogMessage> formatter) {
    final SyslogMessage msg = formatter(record);
    if (msg.message.isNotEmpty) {
      io.BytesBuilder header = new io.BytesBuilder();

      // pri
      header.add('<'.codeUnits);
      header.add(((msg.facility.index << 3) + msg.severity.index)
          .toString().codeUnits);
      header.add('>'.codeUnits);

      // header
      //  timestamp
      String ts = _dateFormat.format(msg.timeStamp);
      if (ts[4] == '0') {
        ts = ts.replaceRange(4, 5, ' ');
      }
      header.add(ts.codeUnits);
      header.add(' '.codeUnits);

      //  hostname
      if (msg.hostname != null) {
        header.add(msg.hostname.split('.').first.codeUnits);
      }
      header.add(' '.codeUnits);

      if (msg.tag != null) {
        header.add(msg.tag.substring(0, math.min(
            31 - msg.sequenceNumber.toString().length,
            msg.tag.length)).codeUnits);
      }
      header.add('-'.codeUnits);
      header.add(msg.sequenceNumber.toString().codeUnits);
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

  Future<Null> _send(List<int> bytes) async {
    if (_socket == null) {
      _socket =
          await io.RawDatagramSocket.bind(io.InternetAddress.ANY_IP_V4, 0);
    }
    print(new String.fromCharCodes(bytes));
    print(_socket.send(bytes, await _config.host, _config.port));
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
  /// 15 - clock daemon
  cron,
  /// 16
  local0,
  /// 17
  local1,
  /// 18
  local2,
  /// 19
  local3,
  /// 20
  local4,
  /// 21
  local5,
  /// 22
  local6,
  /// 23
  local7,
}

class SyslogMessage {
  final Severity severity;
  final Facility facility;
  final DateTime timeStamp;
  final String hostname;
  final String tag;
  final int sequenceNumber;
  final String message;

  const SyslogMessage(this.severity, this.facility, this.timeStamp,
      this.hostname, this.tag, this.sequenceNumber, this.message);
}

const int maxMessageLength = 1024;
const String splitter = '\n>>>\n';

class SimpleSyslogFormatter extends FormatterBase<SyslogMessage> {
  const SimpleSyslogFormatter() : super();

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
        io.Platform.localHostname, tag, record.sequenceNumber, message);
  }
}
