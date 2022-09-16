require_relative '../command'
require_relative '../outputs'

module Profile
  module Commands
    class Clean < Command
      include Profile::Outputs
      def run
        hostnames = args[0]
        if hostnames
          hostnames.split(',').each do |hostname|
            node = Node.find(hostname)
            if node.status == 'failed'
              node.delete
            else
              say_warning "Node '#{hostname}' has not failed setup so will not be removed"
            end
          end
        else
          Node.all.each do |node|
            if node.status && node.delete
              puts "Node '#{node.hostname}' removed from inventory."
            end
          end
        end
      end
    end
  end
end
