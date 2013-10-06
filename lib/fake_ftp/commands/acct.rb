require 'fake_ftp/commands/base'

module FakeFtp
  module Command
    class Acct < Base

      def run(*args)
        '230 WHATEVER!'
      end

    end
  end
end
