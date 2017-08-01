# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Quit
      def run(ctx, *)
        ctx.respond_with '221 OMG bye!'
        ctx.client&.close
        ctx.client = nil
      end
    end
  end
end
