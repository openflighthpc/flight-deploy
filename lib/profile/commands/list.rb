require_relative '../command'
require_relative '../config'
require_relative '../table'
require_relative '../node'
module Profile
  module Commands
    class List < Command
      def run
        hunter = @options.include_hunter
        raise "No nodes to display" if !Node.all(hunter: hunter).any?

        t = Table.new
        t.headers('Node', 'Identity', 'Status')
        Node.all.each do |node|
          t.row( node.hostname, node.identity, node.status )
        end
        t.emit
      end
    end
  end
end
