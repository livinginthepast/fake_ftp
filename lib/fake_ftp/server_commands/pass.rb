# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Pass
      def run(*)
        '230 logged in'
      end
    end
  end
end
