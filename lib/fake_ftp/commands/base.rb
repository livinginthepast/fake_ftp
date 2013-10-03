class FakeFtp::Command::Base
  attr_reader :server

  def initialize(server)
    @server = server
  end

  def self.inherited(subclass)
    FakeFtp::Command.push subclass
  end
end
