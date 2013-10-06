module FakeFtp
  module Command
    class Pwd < Base

      def run(*args)
        "257 \"#{server.path}\" is current directory"
      end

    end
  end
end
