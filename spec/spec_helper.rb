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
  def gets_with_timeout(client, timeout: 5, endwith: "\r\n", chunk: 1)
    start = Time.now
    buf = ''
    begin
      if Time.now - start >= timeout
        raise Timeout::Error, "timed out after #{timeout}s"
      end
      loop do
        buf += client.read_nonblock(chunk)
        return buf if buf.end_with?(endwith)
      end
    rescue EOFError
      return buf
    rescue IO::WaitReadable, Errno::EINTR
      IO.select([client], nil, nil, 1)
      sleep 0.1
      retry
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
end
