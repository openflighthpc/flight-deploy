require_relative '../command'

module Profile
  module Commands
    class Clean < Command
      def run
        Node.all.each do |node|
          node.delete if node.status == 'failed'
        end
      end
    end
  end
end
