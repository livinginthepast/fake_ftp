require 'socket'
require "thread"

module FakeFtp
  class Server

    attr_accessor :directory, :port, :passive_port
    attr_reader :files

    CMDS = %w[acct cwd cdup pass pasv port pwd quit stor type user]
    LNBK = "\r\n"

    def initialize(control_port = 21, data_port = nil, options = {})
      self.port = control_port
      self.passive_port = data_port
      raise(Errno::EADDRINUSE, "#{port}") if is_running?
      raise(Errno::EADDRINUSE, "#{passive_port}") if passive_port && is_running?(passive_port)
      @connection = nil
      @data = nil
      @options = options
      @files = []
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

      if passive_port
        @data_server = ::TCPserver.new('127.0.0.1', passive_port)
      end
    end

    def stop
      @started = false
      @client.close if @client
      @server.close if @server
      @server = nil
      @data_server.close if @data_server
      @data_server = nil
    end

    def is_running?(tcp_port = nil)
      service = `lsof -w -n -i tcp:#{tcp_port || port}`
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
          __send__ "_#{command}", message
        else
          '500 Unknown command'
      end
    end

    def _acct(*args)
      '230 WHATEVER!'
    end

    def _cwd(*args)
      '250 OK!'
    end
    alias :_cdup :_cwd

    def _pass(*args)
      '230 logged in'
    end

    def _pasv(*args)
      if passive_port
        p1 = (passive_port / 256).to_i
        p2 = passive_port % 256
        "227 Entering Passive Mode (127,0,0,1,#{p1},#{p2})"
      else
        '502 Aww hell no, use Active'
      end
    end

    def _port(remote)
      # remote = remote.split(',')
      # remote_port = remote[4].to_i * 256 + remote[5].to_i
      # unless @data_connection.nil?
      #   @data_connection.close
      #   @data_connection = nil
      # end
      # puts remote_port
      # @data_connection = ::TCPSocket.open('127.0.0.1', remote_port)
      # '200 Okay'
      '500 Not implemented yet'
    end

    def _pwd(*args)
      "257 \"#{self.directory}\" is current directory"
    end

    def _quit(*args)
      '221 OMG bye!'
    end

    def _stor(filename)
      @files << File.basename(filename.to_s)
      respond_with('125 Do it!')

      data_client = @data_server.accept
      @data = data_client.recv(1024)

      data_client.close
      '226 Did it!'
    end

    def _type(type = 'A')
      case type.to_s
        when 'A'
          '200 Type set to A.'
        when 'I'
          '200 Type set to I.'
        else
          '504 We don\'t allow those'
      end
    end

    def _user(name = '')
      (name.to_s == 'anonymous') ? '230 logged in' : '331 send your password'
    end
  end
end