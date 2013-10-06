require 'fake_ftp/commands/base'

module FakeFtp
  module Command
    class Cdup < Base

      def run(*args)
        '250 OK!'
      end

    end
  end
end
