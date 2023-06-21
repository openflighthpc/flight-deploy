require_relative '../command'
require_relative '../outputs'

module Profile
  module Commands
    class Clean < Command
      include Profile::Outputs
      def run
        hostnames = args[0]
        if hostnames
          not_found = []
          hostnames.split(',').each do |hostname|
            node = Node.find(hostname)
            not_found << hostname && next if !node
            if node.status == 'failed' && node.delete
              puts "Node '#{node.hostname}' removed from inventory."
            else
              say_warning "Node '#{hostname}' has not failed setup so will not be removed"
            end
          end
          if not_found.any?
            say_warning <<~HEREDOC
            The following nodes were not found:
            #{not_found.join("\n")}
            HEREDOC
          end
        else
          Node.all.each do |node|
            if node.status == 'failed' && node.delete
              puts "Node '#{node.hostname}' removed from inventory."
            end
          end
        end
      end
    end
  end
end
