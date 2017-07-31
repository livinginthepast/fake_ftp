require 'socket'
require 'thread'
require 'timeout'

module FakeFtp
  class Server
    attr_accessor :port, :passive_port
    attr_reader :workdir

    CMDS = %w[
      acct
      cwd
      cdup
      dele
      list
      mdtm
      mkd
      nlst
      pass
      pasv
      port
      pwd
      quit
      size
      stor
      retr
      rnfr
      rnto
      type
      user
      site
    ].freeze
    CRLF = "\r\n".freeze

    alias path workdir

    def initialize(control_port = 21, data_port = nil, options = {})
      @port = control_port
      @passive_port = data_port
      @store = {}
      @workdir = '/pub'
      @options = options
      @command_state = {}

      @connection = nil
      @data_server = nil
      @server = nil
      @client = nil

      raise Errno::EADDRINUSE, port.to_s if !control_port.zero? && running?

      if passive_port && !passive_port.zero? && running?(passive_port)
        raise Errno::EADDRINUSE, passive_port.to_s
      end

      self.mode = :active unless options.key?(:mode)
      self.absolute = false unless options.key?(:absolute)
    end

    def files
      @store.values.map do |f|
        if absolute?
          abspath(f.name)
        else
          f.name
        end
      end
    end

    def file(name)
      @store.values.detect do |f|
        if absolute?
          abspath(f.name) == name
        else
          f.name == name
        end
      end
    end

    def reset
      @store.clear
    end

    def add_file(filename, data, last_modified_time = Time.now)
      @store[abspath(filename)] = FakeFtp::File.new(
        filename.to_s, data, options[:mode], last_modified_time
      )
    end

    def start
      @started = true
      @server = ::TCPServer.new('127.0.0.1', port)
      @port = @server.addr[1]
      @thread = Thread.new do
        while @started
          debug('enter client loop')
          @client = begin
                      @server.accept
                    rescue => e
                      debug("error on accept: #{e}")
                      nil
                    end
          next unless @client
          respond_with('220 Can has FTP?')
          @connection = Thread.new(@client) do |socket|
            debug('enter request thread')
            while @started && !socket.nil? && !socket.closed?
              input = begin
                        socket.gets
                      rescue
                        debug("error on socket.gets: #{e}")
                        nil
                      end
              if input
                debug("server client raw: <- #{input.inspect}")
                respond_with(parse(input))
              end
            end
            unless @client.nil?
              @client.close unless @client.closed?
              @client = nil
            end
            debug('leave request thread')
          end
          debug('leave client loop')
        end
        unless @server.nil?
          @server.close unless @server.closed?
          @server = nil
        end
      end

      return unless passive_port
      @data_server = ::TCPServer.new('127.0.0.1', passive_port)
      @passive_port = @data_server.addr[1]
    end

    def stop
      @started = false
      @client.close if @client
      @server.close if @server
      @server = nil
      @data_server.close if @data_server
      @data_server = nil
    end

    def running?(tcp_port = nil)
      tcp_port.nil? ? port_is_open?(port) : port_is_open?(tcp_port)
    end

    alias is_running? running?

    def mode=(value)
      unless %i[active passive].include?(value)
        raise ArgumentError, "invalid mode #{value.inspect}"
      end
      options[:mode] = value
    end

    def mode
      options[:mode]
    end

    def absolute?
      options[:absolute]
    end

    def absolute=(value)
      unless [true, false].include?(value)
        raise ArgumentError, "invalid absolute #{value}"
      end
      options[:absolute] = value
    end

    private

    attr_reader :options

    def abspath(filename)
      return filename if filename.start_with?('/')
      [@workdir.to_s, filename].join('/').gsub('//', '/')
    end

    def respond_with(stuff)
      return if stuff.nil? || @client.nil? || @client.closed?
      debug("server client raw: -> #{stuff.inspect}")
      @client.print(stuff << CRLF)
    end

    def parse(request)
      return if request.nil?
      debug("raw request: #{request.inspect}")
      command = request[0, 4].downcase.strip
      contents = request.split
      message = contents[1..contents.length]
      case command
      when *CMDS
        debug("sending _#{command} #{message.inspect}")
        __send__ "_#{command}", *message
      else
        '500 Unknown command'
      end
    end

    ## FTP commands
    #
    #  Methods are prefixed with an underscore to avoid conflicts with internal
    #  server methods. Methods map 1:1 to FTP command words.
    #
    def _acct(*_args)
      '230 WHATEVER!'
    end

    def _cwd(*args)
      @workdir = args[0]
      @workdir = "/#{@workdir}" unless @workdir.start_with?('/')
      '250 OK!'
    end

    def _cdup(*_args)
      '250 OK!'
    end

    def _list(*args)
      if active? && @command_state[:active_connection].nil?
        respond_with('425 Ain\'t no data port!')
        return
      end

      respond_with('150 Listing status ok, about to open data connection')
      data_client = if active?
                      @command_state[:active_connection]
                    else
                      @data_server.accept
                    end

      wildcards = build_wildcards(args)
      statlines = matching_files(wildcards).map do |f|
        %W[
          -rw-r--r--
          1
          owner
          group
          #{f.bytes}
          #{f.created.strftime('%b %d %H:%M')}
          #{f.name}
        ].join("\t")
      end
      data_client.write(statlines.join("\n"))
      data_client.close
      @command_state[:active_connection] = nil

      '226 List information transferred'
    end

    def _mdtm(filename = '', _local = false)
      respond_with('501 No filename given') && return if filename.empty?
      server_file = file(filename)
      respond_with('550 File not found') && return if server_file.nil?

      respond_with(
        "213 #{server_file.last_modified_time.strftime('%Y%m%d%H%M%S')}"
      )
    end

    def _nlst(*args)
      if active? && @command_state[:active_connection].nil?
        respond_with('425 Ain\'t no data port!')
        return
      end

      respond_with('150 Listing status ok, about to open data connection')
      data_client = if active?
                      @command_state[:active_connection]
                    else
                      @data_server.accept
                    end

      wildcards = build_wildcards(args)
      matching = matching_files(wildcards).map do |f|
        "#{f.name}\n"
      end

      data_client.write(matching.join)
      data_client.close
      @command_state[:active_connection] = nil

      '226 List information transferred'
    end

    def _pass(*_args)
      '230 logged in'
    end

    def _pasv(*_args)
      if passive_port
        options[:mode] = :passive
        p1 = (passive_port / 256).to_i
        p2 = passive_port % 256
        "227 Entering Passive Mode (127,0,0,1,#{p1},#{p2})"
      else
        '502 Aww hell no, use Active'
      end
    end

    def _port(remote = '')
      remote = remote.split(',')
      remote_port = remote[4].to_i * 256 + remote[5].to_i
      unless @command_state[:active_connection].nil?
        @command_state[:active_connection].close
        @command_state[:active_connection] = nil
      end
      options[:mode] = :active
      debug('_port active connection ->')
      @command_state[:active_connection] = ::TCPSocket.new(
        '127.0.0.1', remote_port
      )
      debug('_port active connection <-')
      '200 Okay'
    end

    def _pwd(*_args)
      "257 \"#{path}\" is current directory"
    end

    def _quit(*_args)
      respond_with '221 OMG bye!'
      @client.close if @client
      @client = nil
    end

    def _retr(filename = '')
      respond_with('501 No filename given') if filename.empty?

      f = file(filename.to_s)
      return respond_with('550 File not found') if f.nil?

      if active? && @command_state[:active_connection].nil?
        respond_with('425 Ain\'t no data port!')
        return
      end

      respond_with('150 File status ok, about to open data connection')
      data_client = if active?
                      @command_state[:active_connection]
                    else
                      @data_server.accept
                    end

      data_client.write(f.data)

      data_client.close
      @command_state[:active_connection] = nil
      '226 File transferred'
    end

    def _rnfr(rename_from = '')
      return '501 Send path name.' if rename_from.nil? || rename_from.empty?

      @command_state[:rename_from] = if absolute?
                                       abspath(rename_from)
                                     else
                                       rename_from
                                     end
      '350 Send RNTO to complete rename.'
    end

    def _rnto(rename_to = '')
      return '501 Send path name.' if rename_to.nil? || rename_to.empty?
      return '503 Send RNFR first.' if @command_state[:rename_from].nil?

      f = file(@command_state[:rename_from])
      if f.nil?
        @command_state[:rename_from] = nil
        return '550 File not found.'
      end

      f.name = rename_to
      @command_state[:rename_from] = nil
      '250 Path renamed.'
    end

    def _size(filename)
      respond_with("213 #{file(filename).bytes}")
    end

    def _stor(filename = '')
      if active? && @command_state[:active_connection].nil?
        respond_with('425 Ain\'t no data port!')
        return
      end

      respond_with('125 Do it!')
      data_client = if active?
                      @command_state[:active_connection]
                    else
                      @data_server.accept
                    end

      data = data_client.read(nil)
      @store[abspath(filename)] = FakeFtp::File.new(
        filename.to_s, data, options[:mode]
      )

      data_client.close
      @command_state[:active_connection] = nil
      '226 Did it!'
    end

    def _dele(filename = '')
      files_to_delete = @store.values.select do |f|
        if absolute?
          abspath(::File.basename(filename)) == abspath(f.name)
        else
          ::File.basename(filename) == f.name
        end
      end

      return '550 Delete operation failed.' if files_to_delete.empty?

      @store.reject! do |_, f|
        files_to_delete.include?(f)
      end

      '250 Delete operation successful.'
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
      name.to_s == 'anonymous' ? '230 logged in' : '331 send your password'
    end

    def _mkd(_directory)
      '257 OK!'
    end

    def _site(command)
      "200 #{command}"
    end

    def active?
      options[:mode] == :active
    end

    def port_is_open?(port)
      begin
        Timeout.timeout(1) do
          begin
            TCPSocket.new('127.0.0.1', port).close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            return false
          end
        end
      rescue Timeout::Error => e
        debug("timeout while checking port #{port}: #{e}")
      end

      false
    end

    def build_wildcards(args)
      wildcards = []
      args.each do |arg|
        next unless arg.include? '*'
        wildcards << arg.gsub('*', '.*')
      end
      wildcards
    end

    def matching_files(wildcards)
      if !wildcards.empty?
        @store.values.select do |f|
          wildcards.any? { |wildcard| f.name =~ /#{wildcard}/ }
        end
      else
        @store.values
      end
    end

    def debug(msg)
      return unless options[:debug]
      $stderr.puts("DEBUG:fake_ftp:#{msg}")
    end
  end
end
