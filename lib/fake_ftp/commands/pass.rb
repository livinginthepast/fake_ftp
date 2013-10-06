module FakeFtp
  module Command
    class Pass < Base

      def run(*args)
        '230 logged in'
      end

    end
  end
end
