require_relative '../command'
require_relative '../type'

module Profile
  module Commands
    class Avail < Command
      def run
        raise "No available cluster types" unless Type.all.any?

        t = Table.new
        t.headers('Name', 'ID', 'Description', 'Prepared')
        Type.all.each do |p|
          t.row( p.name, p.id, p.description, p.prepared? )
        end
        t.emit
      end
    end
  end
end
