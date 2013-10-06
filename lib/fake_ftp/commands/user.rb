module FakeFtp
  module Command
    class User < Base

      def run(name = '')
        (name.to_s == 'anonymous') ? '230 logged in' : '331 send your password'
      end

    end
  end
end
