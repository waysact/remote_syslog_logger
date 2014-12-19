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
end
