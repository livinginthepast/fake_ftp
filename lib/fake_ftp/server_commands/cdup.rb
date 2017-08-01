# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Cdup
      def run(*)
        '250 OK!'
      end
    end
  end
end
