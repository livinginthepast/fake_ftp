require 'socket'
require 'thread'

module FakeFtp
  class Server

    attr_accessor :port, :passive_port
    attr_reader :mode

    CMDS = %w[acct cwd cdup pass pasv port pwd quit stor type user]
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
    end

    def files
      @files.map(&:name)
    end

    def file(name)
      @files.detect { |file| file.name == name }
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
        @mode = :passive
        p1 = (passive_port / 256).to_i
        p2 = passive_port % 256
        "227 Entering Passive Mode (127,0,0,1,#{p1},#{p2})"
      else
        '502 Aww hell no, use Active'
      end
    end

    def _port(remote)
      remote = remote.first.split(',')
      remote_port = remote[4].to_i * 256 + remote[5].to_i
      unless @active_connection.nil?
        @active_connection.close
        @active_connection = nil
      end
      @mode = :active
      @active_connection = ::TCPSocket.open('127.0.0.1', remote_port)
      '200 Okay'
    end

    def _pwd(*args)
      "257 \"/pub\" is current directory"
    end

    def _quit(*args)
      respond_with '221 OMG bye!'
      @client.close if @client
      @client = nil
    end

    def _stor(filename)
      if @mode == :passive
        respond_with('125 Do it!')
        data_client = @data_server.accept
      else
        respond_with('425 Ain\'t no data port!') && return if @active_connection.nil?
        respond_with('125 Do it!')

        data_client = @active_connection
      end

      data = data_client.recv(1024)
      file = FakeFtp::File.new(::File.basename(filename.to_s), data.length, @mode)
      @files << file

      data_client.close
      @active_connection = nil
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