# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Acct
      def run(*)
        '230 WHATEVER!'
      end
    end
  end
end
