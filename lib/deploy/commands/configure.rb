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
          Config.fetch(:configuration_questions).each do |question|
            key(question.id).ask(question.text) do |q|
              if Config.fetch(question.id)
                q.default Config.fetch(question.id)
              elsif question.default
                q.default question.default
              end
              q.required question.validation.required
              if question.validation.to_h.key?(:format)
                q.validate Regexp.new(question.validation.format)
                q.messages[:valid?] = question.validation.message
              end
            end
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
