# frozen_string_literal: true

module FakeFtp
  module ServerCommands
    class Dele
      def run(ctx, filename = '', *)
        files_to_delete = ctx.store.values.select do |f|
          if ctx.absolute?
            ctx.abspath(::File.basename(filename)) == ctx.abspath(f.name)
          else
            ::File.basename(filename) == f.name
          end
        end

        return '550 Delete operation failed.' if files_to_delete.empty?

        ctx.store.reject! do |_, f|
          files_to_delete.include?(f)
        end

        '250 Delete operation successful.'
      end
    end
  end
end
