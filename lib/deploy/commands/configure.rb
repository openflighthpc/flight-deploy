require 'tty-prompt'
require_relative '../command'

module Deploy
  module Commands
    class Configure < Command
      def run
        prompt = TTY::Prompt.new
        result = prompt.collect do
          key(:name).ask('Cluster name:', default: 'my-cluster')
          key(:ip).ask('IP range:', required: true)
        end
        ENV['CLUSTER_NAME'] = result[:name]
        ENV['IP_RANGE'] = result[:ip]
      end
    end
  end
end