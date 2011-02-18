require 'socket'

module FakeFtp
  class Server

    attr_accessor :directory, :status, :port, :pid

    CMDS = %w[]
    LNBK = "\r\n"

    def initialize(port = 21)
      self.port = port
    end

    def start
      self.pid = fork do
        accept_connections
      end
    end

    def stop
      Process.kill("ABRT", self.pid)
      self.pid = nil
    end

    def is_running?
      !pid.nil?
    end

    def accept_connections
      begin
        server = ::TCPServer.new('127.0.0.1', port)
        @socket = server.accept
        respond_with("200 Can has FTP!")
        while !(@socket.nil? || @socket.closed?)
          request = @socket.gets
          respond_with parse(request)
        end
      rescue Errno::EADDRINUSE
        puts "address in use"
        exit
      end
    end

    def respond_with(stuff)
      @socket.print stuff << LNBK unless stuff.nil? or @socket.nil? or @socket.closed?
    end

    def parse(request)
      return if request.nil?
      command = request[0,4].downcase.strip
      contents = request.split
      message = contents[1..contents.length]
      case command
        when *CMDS
          __send__ command, message
        else
          respond_with("500 Unknown command")
      end
    end
  end
end