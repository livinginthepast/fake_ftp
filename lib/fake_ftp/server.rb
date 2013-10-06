require 'socket'
require 'thread'
require 'timeout'
require 'fake_ftp/command'

module FakeFtp
  class Server

    attr_accessor :client, :mode, :path, :port, :passive_port

    LNBK = "\r\n"

    def initialize(control_port = 21, data_port = nil, options = {})
      self.port = control_port
      self.passive_port = data_port
      raise(Errno::EADDRINUSE, "#{port}") if is_running?
      raise(Errno::EADDRINUSE, "#{passive_port}") if passive_port && is_running?(passive_port)
      @connection = nil
      @options = options
      @files = []
      @mode = :active
      @path = "/pub"
    end

    def file(name)
      @files.detect { |file| file.name == name }
    end

    def files
      @files.map(&:name)
    end

    def reset
      @files.clear
    end

    def add_file(filename, data, last_modified_time = Time.now)
      @files << FakeFtp::File.new(::File.basename(filename.to_s), data, self.mode, last_modified_time)
    end

    def remove_file(filename)
      @files.delete_if { |f| f.name == filename}
    end

    def close_connection!
      unless self.client.nil?
        self.client.close unless self.client.closed?
        self.client = nil
      end
    end

    def start
      @started = true
      @server = ::TCPServer.new('127.0.0.1', port)
      @thread = Thread.new do
        while @started
          self.client = @server.accept rescue nil
          if self.client
            respond_with('220 Can has FTP?')
            @connection = Thread.new(self.client) do |socket|
              while @started && !socket.nil? && !socket.closed?
                input = socket.gets rescue nil
                respond_with FakeFtp::Command.process(self, input) if input
              end
              close_connection!
            end
          end
        end
        unless @server.nil?
          @server.close unless @server.closed?
          @server = nil
        end
      end

      if passive_port
        @data_server = ::TCPServer.new('127.0.0.1', passive_port)
      end
    end

    def stop
      @started = false
      self.client.close if self.client
      @server.close if @server
      @server = nil
      @data_server.close if @data_server
      @data_server = nil
    end

    def is_running?(tcp_port = nil)
      tcp_port.nil? ? port_is_open?(port) : port_is_open?(tcp_port)
    end

    def active?
      mode == :active
    end

    def respond_with(stuff)
      self.client.print stuff << LNBK unless stuff.nil? or self.client.nil? or self.client.closed?
    end

    private

    def port_is_open?(port)
      begin
        Timeout::timeout(1) do
          begin
            s = TCPSocket.new("127.0.0.1", port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          end
        end
      rescue Timeout::Error
      end

      return false
    end
  end
end
