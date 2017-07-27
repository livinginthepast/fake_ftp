$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

require 'rspec'
require 'fake_ftp'

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
      IO.select([client])
      sleep 0.1
      retry
    end
    buf
  end

  module_function :gets_with_timeout
end
