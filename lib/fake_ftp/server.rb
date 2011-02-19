require 'socket'
require "thread"

module FakeFtp
  class ServerQuit < Exception;
  end

  class Server

    attr_accessor :directory, :port

    CMDS = %w[user pass]
    LNBK = "\r\n"

    def initialize(port = 21)
      self.port = port
      @connections = []
      if self.is_running?
        raise "Port in use: #{port}"
      end
    end

    def start
      @status = :starting
      @server = ::TCPServer.new('127.0.0.1', port)
      @thread = Thread.new do
        begin
          while @status != :closed
            @client = @server.accept
            respond_with('200 Can has FTP?')
            @connections << Thread.new(@client) do |socket|
              parse(socket.gets)
            end
          end
        rescue ServerQuit
          @status = :closed
        ensure
          @thread = nil
        end
      end
    end

    def stop
      @status = :closed
      @server.close
      @server = nil
    end

    def is_running?
      service = `lsof -w -n -i tcp:#{port}`
      !service.nil? && service != ''
    end

    def respond_with(stuff)
      @client.print stuff << LNBK unless stuff.nil? or @client.nil? or @client.closed?
    end

    def parse(request)
      return if request.nil?
      command = request[0, 4].downcase.strip
      contents = request.split
      message = contents[1..contents.length]
      case command
        when *CMDS
          __send__ command, message
        else
          respond_with("500 Unknown command")
      end
    end

    def user(stuff = '')
      '331 send your password'
    end

    def pass(stuff = '')
      '230 logged in'
    end
  end
end