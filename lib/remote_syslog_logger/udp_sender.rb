require 'socket'
require 'syslog_protocol'

module RemoteSyslogLogger
  class UdpSender
    def initialize(remote_hostname, remote_port, options = {})
      @remote_hostname = remote_hostname
      @remote_port     = remote_port
      @whinyerrors     = options[:whinyerrors]
      @max_packet_size = options[:max_packet_size] || 1024
      @continuation_prefix = options[:continuation_prefix] || '... '

      @socket = UDPSocket.new
      @packet = SyslogProtocol::Packet.new

      local_hostname   = options[:local_hostname] || (Socket.gethostname rescue `hostname`.chomp)
      local_hostname   = 'localhost' if local_hostname.nil? || local_hostname.empty?
      @packet.hostname = local_hostname

      @packet.facility = options[:facility] || 'user'
      @packet.severity = options[:severity] || 'notice'
      @packet.tag      = options[:program]  || default_tag
    end

    def default_tag
      pid_suffix = "[#{$$}]"
      max_basename_size = 32 - pid_suffix.size
      "#{File.basename($0)}"[0...max_basename_size].gsub(/[^\x21-\x7E]/, '_') + pid_suffix
    end
    
    def transmit(message)
      message.split(/\r?\n/).each do |line|
        begin
          next if line =~ /^\s*$/
          packet = @packet.dup
          max_content_size = @max_packet_size - packet.assemble(@max_packet_size).size
          offset = 0
          line_prefix = ''
          while offset < line.size
            chunk_size = max_content_size - line_prefix.size
            packet.content = line_prefix + line[offset...offset+chunk_size]
            @socket.send(packet.assemble(@max_packet_size), 0, @remote_hostname, @remote_port)
            offset += chunk_size
            line_prefix = @continuation_prefix
          end
        rescue
          $stderr.puts "#{self.class} error: #{$!.class}: #{$!}\nOriginal message: #{line}"
          raise if @whinyerrors
        end
      end
    end
    
    # Make this act a little bit like an `IO` object
    alias_method :write, :transmit
    
    def close
      @socket.close
    end
  end
end
