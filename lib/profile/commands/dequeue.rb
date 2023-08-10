require_relative '../command'
require_relative './concerns/node_utils'
require_relative '../config'
require_relative '../table'
require_relative '../node'
module Profile
  module Commands
    class Dequeue < Command
      include Concerns::NodeUtils

      def run
        strings = args[0].split(',')
        names = []
        strings.each do |str|
          names.append(expand_brackets(str))
        end

        names.flatten!

        failed = []
        names.each do |name|
          if QueueManager.contains?(name)
            QueueManager.pop(name)
          else
            failed << name
          end
        end

        removed = names - failed
        puts "Nodes removed from queue: #{removed.join(', ')}" unless removed.empty?

        raise "The following nodes were not found in the queue: #{failed.join(', ')}" unless failed.empty?
      end
    end
  end
end
