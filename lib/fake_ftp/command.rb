module FakeFtp
  module Command
    COMMANDS = {}

    def self.find command
      COMMANDS[command]
    end

    def self.process server, request
      message = request.split
      command = message.shift.downcase

      command_class = find(command)

      if command_class
        command_class.new(server).run(*message)
      else
        '500 Unknown command'
      end
    end

    def self.push klass
      COMMANDS[klass.name.downcase] = klass
    end

  end
end

#require 'fake_ftp/commands/base'
#require 'fake_ftp/commands/acct'
#require 'fake_ftp/commands/cdup'
#require 'fake_ftp/commands/cwd'
#require 'fake_ftp/commands/dele'
#require 'fake_ftp/commands/list'
#require 'fake_ftp/commands/mdtm'
#require 'fake_ftp/commands/mkd'
#require 'fake_ftp/commands/nlst'
#require 'fake_ftp/commands/pass'
#require 'fake_ftp/commands/pasv'
#require 'fake_ftp/commands/port'
#require 'fake_ftp/commands/pwd'
#require 'fake_ftp/commands/quit'
#require 'fake_ftp/commands/retr'
#require 'fake_ftp/commands/rnfr'
#require 'fake_ftp/commands/rnto'
#require 'fake_ftp/commands/stor'
#require 'fake_ftp/commands/type'
#require 'fake_ftp/commands/user'
