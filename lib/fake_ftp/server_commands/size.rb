# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Size
      def run(ctx, filename, *)
        ctx.respond_with("213 #{ctx.file(filename).bytes}")
      end
    end
  end
end
