require 'logger'

module FakeFtp
  class Server

    attr_accessor :directory, :status, :port

    CMDS = %w[]
    LNBK = "\r\n"

    def initialize(port = 21, *args)
      self.port = port
      @status = :dead
      @logger = ::Logger.new(STDERR)
    end

    def start
#      @server = TCPServer.new('127.0.0.1', port)
      @status = :started
    end

    def stop
#      @server.close
      @status = :dead
    end

    def is_running?
      @status != :dead
    end

  end
end