require 'socket'
require "thread"

module FakeFtp
  class Server

    attr_accessor :directory, :port

    CMDS = %w[acct cwd cdup pass pasv pwd quit type user]
    LNBK = "\r\n"

    def initialize(port = 21, options = {})
      self.port = port
      raise(Errno::EADDRINUSE, "#{port}") if is_running?
      @connection = nil
      @options = options
      self.directory = "#{Rails.root}/tmp/ftp" rescue '/tmp'
    end

    def start
      @started = true
      @server = ::TCPServer.new('127.0.0.1', port)
      @thread = Thread.new do
        while @started
          @client = @server.accept
          respond_with('200 Can has FTP?')
          @connection = Thread.new(@client) do |socket|
            while @started && !socket.nil? && !socket.closed?
              respond_with parse(socket.gets)
            end
            @client.close
            @client = nil
          end
        end
        @server.close
        @server = nil
      end
    end

    def stop
      @started = false
      @client.close if @client
      @server.close if @server
      @server = nil
    end

    def is_running?
      service = `lsof -w -n -i tcp:#{port}`
      !service.nil? && service != ''
    end

    private

    def respond_with(stuff)
      @client.print stuff << LNBK unless stuff.nil? or @client.nil? or @client.closed?
    end

    def parse(request)
      return if request.nil?
      puts request if @options[:debug]
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

    def acct(*args)
      '230 WHATEVER!'
    end

    def cwd(*args)
      '250 OK!'
    end
    alias :cdup :cwd

    def pass(*args)
      '230 logged in'
    end

    def pasv(*args)
      '227 Entering Passive Mode (128,205,32,24,82,127)'
    end

    def pwd(*args)
      "257 \"#{self.directory}\" is current directory"
    end

    def quit(*args)
      '221 OMG bye!'
    end

    def type(type = 'A')
      case type.to_s
        when 'A'
          '200 Type set to A.'
        when 'I'
          '200 Type set to I.'
        else
          '504 We don\'t allow those'
      end
    end

    def user(name = '')
      (name.to_s == 'anonymous') ? '230 logged in' : '331 send your password'
    end
  end
end