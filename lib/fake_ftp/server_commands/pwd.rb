# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Pwd
      def run(ctx, *)
        "257 \"#{ctx.workdir}\" is current directory"
      end
    end
  end
end
