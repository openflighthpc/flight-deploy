require 'tty-prompt'
require 'yaml'
require 'json'
require_relative '../command'
require_relative '../type'

module Profile
  module Commands
    class Configure < Command
      def run
        if @options.show
          display_details
        else
          raise "No valid cluster type given to configure" unless cluster_type
          answers = case @options.answers.nil?
                    when true
                      ask_questions
                    when false
                      use_cli_answers
                    end
          save_answers(answers)
        end
      end

      private

      def use_cli_answers
        cli_answers.tap do |a|
          given = a&.keys || []
          required = cluster_type.questions.each.map(&:id)
          if !(required - given).empty?
            raise "The following questions were not answered by the JSON data: #{(required - given).join(", ")}"
          elsif !(given - required).empty?
            raise "The following given answers are not recognised by the cluster type: #{(given - required).join(", ")}"
          end
        end
      end

      def ask_questions
        type = cluster_type

        prompt.collect do
          type.questions.each do |question|
            key(question.id).ask(question.text) do |q|
              prefill = type.fetch_answer(question.id)
              if question.default_smart && prefill.nil?
                process = Flight::Subprocess::Local.new(
                  env: {},
                  logger: smart_log,
                  timeout: 5,
                )
                result = process.run(question.default_smart, nil)
                output = result.stdout.chomp
                if !result.success?
                  smart_log.debug("Command '#{question.default_smart}' failed to run: #{result.stderr}")
                elsif output.match(Regexp.new(question.validation.format))
                  prefill ||= output
                else
                  smart_log.debug("Command result '#{output}' did not pass validation check for '#{question.text}'")
                end
              end
              prefill ||= question.default
              q.default prefill

              q.required question.validation.required
              if question.validation.to_h.key?(:format)
                q.validate Regexp.new(question.validation.format)
                q.messages[:valid?] = question.validation.message
              end
            end
          end
        end
      end

      def display_details
        raise "Cluster has not yet been configured - please run `configure`" unless Config.cluster_type
        type = Type.find(Config.cluster_type)
        raise "Invalid cluster type has been saved - please rerun `configure`" unless type

        puts "Cluster type: #{type.name}"
        type.questions.each do |question|
          puts "#{question.text} #{ type.fetch_answer(question.id) || 'none' }"
        end
      end

      def save_answers(answers)
        Config.data.set(:cluster_type, value: cluster_type.id)
        Config.save_data
        cluster_type.save_answers(answers)
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end

      def smart_log
        @smart_log ||= Logger.new(File.join(Config.log_dir, 'configure.log'))
      end

      def cli_answers
        return nil unless @options.answers
        @cli_answers ||= JSON.load(@options.answers)
      rescue JSON::ParserError
        raise <<~ERROR.chomp
        Error parsing answers JSON:
        #{$!.message}
        ERROR
      end

      def cluster_type
        @type ||= Type.find(
          cli_answers&.delete('cluster_type'), Config.cluster_type
        ) || Type.find(
          prompt.select('Cluster type: ', Type.all.map { |t| t.name })
        )
      end
    end
  end
end
