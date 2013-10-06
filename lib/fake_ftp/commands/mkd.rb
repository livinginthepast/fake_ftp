module FakeFtp
  module Command
    class Mkd < Base

      def run(directory)
        "257 OK!"
      end

    end
  end
end
