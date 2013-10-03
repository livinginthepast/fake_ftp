class FakeFtp::Command::Pass < Base

  def run(*args)
    '230 logged in'
  end

end
