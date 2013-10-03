class FakeFtp::Command::Acct < Base

  def run(*args)
    '250 OK!'
  end

end
