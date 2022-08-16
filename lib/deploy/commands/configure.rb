require 'tty-prompt'
require 'yaml'
require_relative '../command'

module Deploy
  module Commands
    class Configure < Command
      def run
        if @options.show
          display_details
        else
          ask = true
          while ask
            ask_questions
            ask = false if prompt.yes?("\nAre these details correct?")
          end
          save_answers
        end
      end

      private

      def display_details
        puts "Cluster name: #{Config.config.cluster_name || '(none)'}"
        puts "IP range: #{Config.config.ip_range || '(none)'}"
      end

      def ask_questions
        puts "\n"
        @answers = prompt.collect do
          key(:cluster_name).ask('Cluster name:') do |q|
            q.default 'my-cluster'
            q.validate /^[a-zA-Z0-9_\-]+$/
            q.messages[:valid?] = "Invalid cluster name: %{value}. " \
              "Must contain only alphanumeric characters, '-' and '_'."
          end
          key(:ip_range).ask('IP range:') do |q|
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

      def save_answers
        raise 'Attempted to save answers without answering questions' unless @answers
        Config.append_to_config(@answers)
      end
    end
  end
end
