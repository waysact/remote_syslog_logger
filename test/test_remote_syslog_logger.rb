require File.expand_path('../helper', __FILE__)

class TestRemoteSyslogLogger < Test::Unit::TestCase
  def setup
    @server_port = rand(50000) + 1024
    @socket = UDPSocket.new
    @socket.bind('127.0.0.1', @server_port)
  end
  
  def test_logger
    @logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    @logger.info "This is a test"
    
    message, addr = *@socket.recvfrom(1024)
    assert_match /This is a test/, message
  end

  def test_logger_multiline
    @logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    @logger.info "This is a test\nThis is the second line"

    message, addr = *@socket.recvfrom(1024)
    assert_match /This is a test/, message

    message, addr = *@socket.recvfrom(1024)
    assert_match /This is the second line/, message
  end

  def test_logger_default_tag
    $0 = 'foo'
    logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    logger.info ""

    message, addr = *@socket.recvfrom(1024)
    assert_match "foo[#{$$}]: I,", message
  end

  def test_logger_long_default_tag
    $0 = 'x' * 64
    pid_suffix = "[#{$$}]"
    logger = RemoteSyslogLogger.new('127.0.0.1', @server_port)
    logger.info ""

    message, addr = *@socket.recvfrom(1024)
    assert_match 'x' * (32 - pid_suffix.size) + pid_suffix + ': I,', message
  end

  TEST_TAG = 'foo'
  TEST_HOSTNAME = 'bar'
  TEST_FACILITY = 'user'
  TEST_SEVERITY = 'notice'
  TEST_MESSAGE = "abcdefg" * 512

  def test_logger_long_message
    _test_msg_splitting_with(
      tag: TEST_TAG,
      hostname: TEST_HOSTNAME,
      severity: TEST_SEVERITY,
      facility: TEST_FACILITY,
      message: TEST_MESSAGE,
      max_packet_size: nil,
      continuation_prefix: nil)
  end

  def test_logger_long_message_custom_packet_size
    _test_msg_splitting_with(
      tag: TEST_TAG,
      hostname: TEST_HOSTNAME,
      severity: TEST_SEVERITY,
      facility: TEST_FACILITY,
      message: TEST_MESSAGE,
      max_packet_size: 2048,
      continuation_prefix: nil)
  end

  def test_logger_long_message_custom_continuation
    _test_msg_splitting_with(
      tag: TEST_TAG,
      hostname: TEST_HOSTNAME,
      severity: TEST_SEVERITY,
      facility: TEST_FACILITY,
      message: TEST_MESSAGE,
      max_packet_size: nil,
      continuation_prefix: 'frobnicate')
  end

  private

  class MessageOnlyFormatter < ::Logger::Formatter
    def call(severity, timestamp, progname, msg)
      msg
    end
  end

  def _test_msg_splitting_with(options)
    logger = RemoteSyslogLogger.new('127.0.0.1', @server_port,
                                    program: options[:tag],
                                    local_hostname: options[:hostname],
                                    severity: options[:severity],
                                    facility: options[:facility],
                                    max_packet_size: options[:max_packet_size],
                                    continuation_prefix: options[:continuation_prefix])
    logger.formatter = MessageOnlyFormatter.new
    logger.info options[:message]

    packet_size = options[:max_packet_size] || 1024
    continuation_prefix = options[:continuation_prefix] || '... '

    test_packet = SyslogProtocol::Packet.new
    test_packet.hostname = options[:hostname]
    test_packet.tag = options[:tag]
    test_packet.severity = options[:severity]
    test_packet.facility = options[:facility]
    test_packet.content = ''
    max_content_size = packet_size - test_packet.assemble.size

    offset = 0
    line_prefix = ''
    while offset < options[:message].size
      chunk_size = max_content_size - line_prefix.size
      message, addr = *@socket.recvfrom(packet_size * 2)
      assert_match Regexp.new(': ' + line_prefix + Regexp.escape(options[:message][offset...offset + chunk_size]) + '$'), message
      offset += chunk_size
      line_prefix = continuation_prefix
    end
  end
end
