require_relative '../command'
require_relative '../config'
require_relative '../table'
require_relative '../node'
module Profile
  module Commands
    class List < Command
      def run
        hunter = Config.use_hunter?
        nodes = Node.all(include_hunter: hunter)
        raise "No nodes to display" unless nodes.any?

        t = Table.new
        t.headers('Node', 'Identity', 'Status')
        nodes.each do |node|
          identity = case QueueManager.contains?(node.name)
                     when true
                       QueueManager.identity(node.name)
                     else
                       node.identity
                     end
          t.row(
            node.name,
            identity,
            node.status
          )
        end
        t.emit
      end
    end
  end
end
