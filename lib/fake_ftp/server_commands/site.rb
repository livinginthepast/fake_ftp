# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Site
      def run(_, command, *)
        "200 #{command}"
      end
    end
  end
end
