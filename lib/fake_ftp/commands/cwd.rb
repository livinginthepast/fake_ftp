module FakeFtp
  module Command
    class Cwd < Base

      def run(*args)
        server.path = args[0]
        server.path = "/#{server.path}" if server.path[0].chr != "/"
        '250 OK!'
      end

    end
  end
end
