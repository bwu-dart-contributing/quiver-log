part of bwu_log.syslog_appender;

class SyslogAppender extends Appender<SyslogMessage> {
  io.InternetAddress _syslogHost;
  final int port;
  io.RawDatagramSocket _socket;
  SyslogAppender(Formatter<SyslogMessage> formatter,{
      io.InternetAddress syslogHost, this.port: 514})
      : super(formatter) {
    if (syslogHost != null) {
      _syslogHost = syslogHost;
    } else {
      _syslogHost = io.InternetAddress.LOOPBACK_IP_V4;
    }
  }

  static final DateFormat _dateFormat = new DateFormat("MMM dd hh:mm:ss");

  void append(LogRecord record, Formatter<SyslogMessage> formatter) {
    final SyslogMessage msg = formatter(record);
    if(msg.message.isNotEmpty) {
      io.BytesBuilder header = new io.BytesBuilder();

      // pri
      header.add('<'.codeUnits);
      header.add(((msg.facility.index << 3) + msg.severity.index).toString().codeUnits);
      header.add('>'.codeUnits);

      // header
      //  timestamp
      String ts = _dateFormat.format(msg.timeStamp);
      if(ts[4] == '0') {
        ts = ts.replaceRange(4,5, ' ');
      }
      header.add(ts.codeUnits);
      header.add(' '.codeUnits);

      //  hostname
      if(msg.hostname != null) {
        header.add(msg.hostname.split('.').first.codeUnits);
      }
      header.add(' '.codeUnits);

      if(msg.tag != null) {
        header.add(msg.tag.substring(0, math.min(31 - msg.sequenceNumber.toString().length, msg.tag.length)).codeUnits);
      }
      header.add('-'.codeUnits);
      header.add(msg.sequenceNumber.toString().codeUnits);
      header.add(':'.codeUnits);

      int pos = 0;
      final maxPartLen = maxMessageLength - header.length;

      while(pos < msg.message.length) {
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
    if(_socket == null) {
      _socket = await io.RawDatagramSocket.bind(io.InternetAddress.ANY_IP_V4, 0);
    }
    print(new String.fromCharCodes(bytes));
    print(_socket.send(bytes, _syslogHost, port));
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

class SyslogFormatter extends FormatterBase<SyslogMessage> {
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
    if(message == null) {
      message = '';
    }
    if(record.error != null) {
      message = '${message}${splitter}${record.error}';
    }
    if(record.stackTrace != null) {
      message = '${message}${splitter}${record.stackTrace}';
    }

    String tag = record.loggerName;

    return new SyslogMessage(severity, Facility.user, record.time, io.Platform.localHostname, tag, record.sequenceNumber, message);
  }
}
