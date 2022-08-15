require 'tty-prompt'
require_relative '../command'

module Deploy
  module Commands
    class Configure < Command
      def run
        ask = true
        while ask
          ask_questions
          ask = false if prompt.yes?("\nAre these details correct?")
        end
        ENV['CLUSTER_NAME'] = @result[:name]
        ENV['IP_RANGE'] = @result[:ip]
      end

      private

      def ask_questions
        puts "\n"
        @result = prompt.collect do
          key(:name).ask('Cluster name:', default: 'my-cluster')
          key(:ip).ask('IP range:', required: true)
        end
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end
    end
  end
end