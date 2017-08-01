# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Type
      def run(_, type = 'A', *)
        case type.to_s
        when 'A'
          '200 Type set to A.'
        when 'I'
          '200 Type set to I.'
        else
          '504 We don\'t allow those'
        end
      end
    end
  end
end
