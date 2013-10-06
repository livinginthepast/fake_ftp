module FakeFtp
  module Command
    class Dele < Base

      def run(filename = '')
        file = server.file(filename)
        return '550 Delete operation failed.' unless file

        server.remove_file(filename)

        '250 Delete operation successful.'
      end

    end
  end
end
