# frozen_string_literal: true

require 'socket'
require 'thread'
require 'timeout'

module FakeFtp
  class Server
    attr_accessor :client, :command_state, :data_server, :passive_port
    attr_accessor :port, :store, :workdir

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

      self.mode = options.fetch(:mode, :active)
      self.absolute = options.fetch(:absolute, false)
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
                      socket.close && break if socket.eof?
                      socket.gets
                    rescue
                      debug("error on socket.gets: #{e}")
                      nil
                    end

              if input
                debug("server client raw: <- #{input.inspect}")
                respond_with(handle_request(input))
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
      @client&.close
      @server&.close
      @server = nil
      @data_server&.close
      @data_server = nil
    end

    def running?(tcp_port = nil)
      return port_is_open?(port) if tcp_port.nil?
      port_is_open?(tcp_port)
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

    attr_reader :options
    private :options

    def abspath(filename)
      return filename if filename.start_with?('/')
      [@workdir.to_s, filename].join('/').gsub('//', '/')
    end

    def respond_with(stuff)
      return if stuff.nil? || @client.nil? || @client.closed?
      debug("server client raw: -> #{stuff.inspect}")
      @client.print(stuff + "\r\n")
    end

    private def handle_request(request)
      return if request.nil?
      debug("raw request: #{request.inspect}")
      command = request[0, 4].downcase.strip
      contents = request.split
      message = contents[1..contents.length]

      inst = load_command_instance(command)
      return "500 Unknown command #{command.inspect}" if inst.nil?
      debug(
        "running command #{command.inspect} " \
        "#{inst.class.name}#run(*#{message.inspect})"
      )
      inst.run(*([self] + message))
    end

    private def load_command_instance(command)
      require "fake_ftp/server_commands/#{command}"
      FakeFtp::ServerCommands.constants.each do |const_name|
        next unless const_name.to_s.downcase == command
        return FakeFtp::ServerCommands.const_get(const_name).new
      end
      nil
    rescue LoadError => e
      debug("failed to require #{command.inspect} class: #{e}")
      nil
    end

    def active?
      options[:mode] == :active
    end

    private def port_is_open?(port)
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
