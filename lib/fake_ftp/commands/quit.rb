class FakeFtp::Command::Quit < Base

  def run(*args)
    respond_with '221 OMG bye!'
    server.client.close if server.client
    server.client = nil
  end

end
