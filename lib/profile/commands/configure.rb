require 'tty-prompt'
require 'yaml'
require 'json'
require_relative '../command'
require_relative '../type'

module Profile
  module Commands
    class Configure < Command
      def run
        if @options.answers
          @answers = JSON.load(@options.answers)
        end

        if @options.show
          display_details
        else
          ask_questions
          save_answers
        end
      end

      private

      def display_details
        raise "Cluster has not yet been configured - please run `configure`" unless Config.cluster_type
        type = Type.find(Config.cluster_type)
        raise "Invalid cluster type has been saved - please rerun `configure`" unless type

        puts "Cluster type: #{type.name}"
        type.questions.each do |question|
          puts "#{question.text} #{ type.fetch_answer(question.id) || 'none' }"
        end
      end

      def ask_questions
        raise "No valid cluster types available" if !Type.all.any?
        type = cluster_type
        raise "Valid cluster type not provided" if !type
        if @options.answers
          given = @answers.keys
          required = @type.questions.each.map(&:id)
          if !(required - given).empty?
            raise "The following questions were not answered by the JSON data: #{(required - given).join(", ")}"
          elsif !(given - required).empty?
            raise "The following given answers are not recognised by the cluster type: #{(given - required).join(", ")}"
          end
        else
          smart_log = Logger.new(File.join(Config.log_dir,'configure.log'))
          @answers = prompt.collect do
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
      end

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end

      def cluster_type
        return @type if @type
        if @options.answers
          if @answers.key?("cluster_type")
            @type ||= Type.find(@answers.delete("cluster_type"))
          else
            @type ||= Type.find(Config.cluster_type)
          end
        else
          @type ||= Type.find( Config.cluster_type || prompt.select('Cluster type: ', Type.all.map { |t| t.name }) )
        end
      end

      def save_answers
        raise 'Attempted to save answers without answering questions' unless @answers
        Config.data.set(:cluster_type, value: cluster_type.id)
        Config.save_data
        cluster_type.save_answers(@answers)
      end
    end
  end
end
