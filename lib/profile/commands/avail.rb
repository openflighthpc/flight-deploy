require_relative '../command'
require_relative '../type'

module Deploy
  module Commands
    class Avail < Command
      def run
        raise "No available cluster types" unless Type.all.any?

        t = Table.new
        t.headers('Name', 'ID', 'Description')
        Type.all.each do |p|
          t.row( p.name, p.id, p.description )
        end
        t.emit
      end
    end
  end
end