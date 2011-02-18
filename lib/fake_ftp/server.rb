require 'logger'

module FakeFtp
  class Server < TCPServer
    attr_accessor :directory, :status, :port

    CMDS = %w[]
    LNBK = "\r\n"

    def initialize(port = 21, *args)
      self.port = port
      @status = :dead
      @logger = ::Logger.new(STDERR)
    end

    def start
      @status = :started
    end

    def stop
      @status = :dead
    end

    def is_running?
      @status != :dead
    end
  end
end