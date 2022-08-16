require 'tty-prompt'
require 'yaml'
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
        save_answers
      end

      private

      def ask_questions
        puts "\n"
        @answers = prompt.collect do
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

      def save_answers
        raise 'Attempted to save answers without answering questions' unless @answers
        config = YAML.load_file(Config.config_path)
        config['cluster_name'] = @answers[:name]
        config['ip_range'] = @answers[:ip].to_s
        File.write(Config.config_path, YAML.dump(config))
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end
    end
  end
end