module FakeFtp
  module Command
    class Rnto < Base

      def run(rename_to='')
        return '501 Send path name.' if rename_to.nil? || rename_to.size < 1

        return '503 Send RNFR first.' unless @rename_from

        if file = file(@rename_from)
          file.name = rename_to
          @rename_from = nil
          '250 Path renamed.'
        else
          @rename_from = nil
          '550 File not found.'
        end
      end

    end
  end
end
