class FakeFtp::Command::Acct < Base

  def run(*args)
    '230 WHATEVER!'
  end

end
