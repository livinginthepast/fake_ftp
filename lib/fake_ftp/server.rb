require 'socket'
require "thread"

module FakeFtp
  class Server

    attr_accessor :directory, :port

    CMDS = %w[acct pass pasv user]
    LNBK = "\r\n"

    def initialize(port = 21)
      self.port = port
      @connection = nil
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
            @connection = Thread.new(@client) do |socket|
              while !socket.nil? && !socket.closed?
                parse(socket.gets)
              end
            end
          end
        end
      end
    end

    def stop
      @status = :closed
      @thread = nil
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

    def user(name = '')
      message = (name.to_s == 'anonymous') ? '230 logged in' : '331 send your password'
      respond_with message
    end

    def pass(*args)
      respond_with '230 logged in'
    end

    def pasv(*args)
      respond_with '227 Entering Passive Mode (128,205,32,24,82,127)'
    end

    def acct(*args)
      respond_with '230 WHATEVER!'
    end
  end
end