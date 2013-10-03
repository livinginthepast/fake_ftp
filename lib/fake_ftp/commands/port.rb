class FakeFtp::Command::Port < Base

  def run(remote = '')
    remote = remote.split(',')
    remote_port = remote[4].to_i * 256 + remote[5].to_i
    unless @active_connection.nil?
      @active_connection.close
      @active_connection = nil
    end
    server.mode = :active
    @active_connection = ::TCPSocket.open('127.0.0.1', remote_port)
    '200 Okay'
  end

end
