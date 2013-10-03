module FakeFtp
  module Command
    COMMANDS = []

    def self.push klass
      COMMANDS[klass.class_name] = klass
    end

    def self.find command
      COMMANDS[command]
    end
  end
end

require 'fake_ftp/commands/base'
