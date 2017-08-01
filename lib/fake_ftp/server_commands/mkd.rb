# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Mkd
      def run(*)
        '257 OK!'
      end
    end
  end
end
