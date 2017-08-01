# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class User
      def run(_, name, *)
        return '230 logged in' if name.to_s == 'anonymous'
        '331 send your password'
      end
    end
  end
end
