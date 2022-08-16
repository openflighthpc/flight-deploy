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
          key(:name).ask('Cluster name:') do |q|
            q.default 'my-cluster'
            q.validate /^[a-zA-Z0-9_\-]+$/
            q.messages[:valid?] = "Invalid cluster name: %{value}. " \
              "Must contain only alphanumeric characters, '-' and '_'."
          end
          key(:ip).ask('IP range:') do |q|
            q.required true
            q.validate /^[0-9\/.]+$/
            q.messages[:valid?] = "Invalid IP range: %{value}. " \
              "Must contain only 0-9, '.' and '/'."
          end
        end
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end
    end
  end
end