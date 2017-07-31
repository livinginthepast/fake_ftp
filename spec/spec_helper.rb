$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

require 'rspec'
require 'fake_ftp'

RSpec.configure do |c|
  c.filter_run_excluding(
    functional: ENV['FUNCTIONAL_SPECS'] != '1',
    integration: ENV['INTEGRATION_SPECS'] != '1'
  )
end

module SpecHelper
  def gets_with_timeout(client, timeout: 5, endwith: "\r\n", chunk: 1024)
    outer_caller = caller(0..1).last.to_s
    start = Time.now
    buf = ''
    loop do
      if Time.now - start >= timeout
        raise Timeout::Error, "client=#{client} timeout=#{timeout}s " \
              "buf=#{buf.inspect} caller=#{outer_caller.inspect}"
      end
      bytes = client.read_nonblock(chunk, exception: false)
      return buf if bytes.nil?
      buf += bytes unless bytes == :wait_readable
      return buf if buf.end_with?(endwith)
    end
    buf
  end

  module_function :gets_with_timeout

  def local_addr_bits(port)
    [
      127, 0, 0, 1,
      port / 256,
      port % 256
    ].map(&:to_s).join(',')
  end

  module_function :local_addr_bits

  def wait_for(timeout: 5)
    outer_caller = caller(0..1).last.to_s
    start = Time.now
    if Time.now - start >= timeout
      raise Timeout::Error, "timeout=#{timeout}s caller=#{outer_caller.inspect}"
    end
    return if yield
    sleep 0.01
  end

  module_function :wait_for

  class FakeDataServer
    def initialize(port)
      @port = port
    end

    attr_reader :port

    def addr_bits
      ::SpecHelper.local_addr_bits(port)
    end

    def start
      server
    end

    def stop
      server.close
    end

    def handler_sock
      @handler_sock ||= wait_for_handler_sock
    end

    private

    def wait_for_handler_sock
      sock = nil

      while sock.nil? || sock == :wait_readable
        sleep 0.01
        sock = server.accept_nonblock(exception: false)
      end

      sock
    end

    def server
      @server ||= TCPServer.new('127.0.0.1', port).tap do |srv|
        srv.sync = true
      end
    end
  end
end
