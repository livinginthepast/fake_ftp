class FakeFtp::Command::Mkd < Base

  def run(directory)
    "257 OK!"
  end

end
