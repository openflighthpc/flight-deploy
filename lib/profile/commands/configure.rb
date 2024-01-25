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
          validate_answers(answers)
          save_answers(answers)
        end
      end

      private

      def use_cli_answers
        cli_answers.tap do |as|
          given = as&.keys || []
          all_questions = cluster_type.recursive_questions
          invalid_boolean_answers = all_questions.select { |q| q.type == 'boolean' && !as[q.id].is_a?(TrueClass) && !as[q.id].is_a?(FalseClass) && !as[q.id].nil? }.map(&:id)
          raise "The following questions requires boolean answers: #{invalid_boolean_answers.join(", ")}" unless invalid_boolean_answers.empty?
          
          if @options.accept_defaults
            generate_prefills(cluster_type.questions)
            all_questions.each do |question|
              as[question.id] ||= @prefills[question.id] unless @prefills[question.id].nil?
            end
          end
          missing = missing_answers(as)
          raise "The following questions were not answered by the JSON data: #{missing.join(", ")}" unless missing.empty?

          required = required_answers(as)
          invalid = given - required
          raise "The following given answers are not recognised by the cluster type: #{invalid.join(", ")}" unless invalid.empty?
        end
      end

      def missing_answers(answers, questions = cluster_type.questions, parent_answer = nil)
        [].tap do |ma|
          questions.each do |q|
            next unless parent_answer.nil? || parent_answer == q.where
            if answers[q.id].nil?
              ma << q.id
            else
              ma.concat(missing_answers(answers, q.questions, answers[q.id])) if q.questions
            end
          end
        end
      end

      def required_answers(answers, questions = cluster_type.questions, parent_answer = nil)
        [].tap do |ra|
          questions.each do |q|
            next unless parent_answer.nil? || parent_answer == q.where
            ra << q.id
            ra.concat(required_answers(answers, q.questions, answers[q.id])) if q.questions
          end
        end
      end

      def ask_questions
        type = cluster_type
        smart_log = Logger.new(File.join(Config.log_dir, 'configure.log'))

        Thread.fork do
          generate_prefills(type.questions)
        end

        collect_answers(type.questions)
      end

      def collect_answers(questions, parent_answer = nil)
        {}.tap do |ans|
          questions.each do |question|
            sleep(0.25) until @prefills && !@prefills[question.id].nil?
            if parent_answer.nil? || parent_answer == question.where
              # conditional question
              if question.type == "boolean"
                ans[question.id] = prompt.yes?(question.text) do |q|
                  q.default @prefills[question.id]
                  q.required question.validation.required
                end
              # general questions
              else
                ans[question.id] = prompt.ask(question.text) do |q|
                  q.default @prefills[question.id]
                  q.required question.validation.required
                  if question.validation.to_h.key?(:format)
                    q.validate Regexp.new(question.validation.format)
                    q.messages[:valid?] = question.validation.message
                  end
                end
              end
              # collect the answers to the child questions
              ans.merge!(collect_answers(question.questions, ans[question.id])) if question.questions
            end
          end
        end
      end


      def generate_prefills(questions)
        @prefills ||= {}
        questions.each do |question|
          smart_log = Logger.new(File.join(Config.log_dir, 'configure.log'))

          prefill = cluster_type.fetch_answer(question.id)
          if question.default_smart && prefill.nil?
            prefill ||= best_command_output(command_list: question.default_smart,
                                            log: smart_log,
                                            regex: question.validation&.has_key?(:format) ? question.validation.format : nil)
          end
          @prefills[question.id] =
            if !prefill.nil?
              prefill
            elsif !question.default.nil?
              question.default
            else
              ""
            end
          generate_prefills(question.questions) if question.questions
        end
      end

      def best_command_output(command_list:, log:, regex: nil)
        outputs = []
        command_list.each_with_index do |command, index|
          Thread.fork do
            process = Flight::Subprocess::Local.new(
              env: {},
              logger: log,
              timeout: 5
            )
            result = process.run(command, nil)
            outputs[index] = result
          end
        end
        command_index = 0
        while command_index < command_list.length
          while outputs[command_index].nil?
            sleep(0.2)
          end
          output = outputs[command_index].stdout.chomp
          if !outputs[command_index].success?
            log.debug("Command '#{command_list[command_index]}' failed to run: #{outputs[command_index].stderr.dump}")
          elsif (regex.nil? || output.match(Regexp.new(regex)))
            return output
          else
            log.debug("Command result '#{output}' did not pass validation check")
          end
          command_index += 1
        end
        nil
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

      def cli_answers
        return nil unless @options.answers
        @cli_answers ||= JSON.load(@options.answers)
      rescue JSON::ParserError
        raise <<~ERROR.chomp
        Error parsing answers JSON:
        #{$!.message}
        ERROR
      end

      def validate_answers(answers)
        bad_answers = []
        cluster_type.recursive_questions.each do |q|
          next unless q.validation.has_key?(:format)
          criterion = Regexp.new(q.validation.format)
          bad_answers << q.id if answers[q.id] && !answers[q.id].match(criterion)
        end
        return unless bad_answers.any?

        raise <<~ERROR.chomp
        The following answers did not pass validation: #{bad_answers.join(', ')}
        ERROR
      end

      def cluster_type
        @type ||=
          if @options.answers
            if @options.reset_type
              Type.find(cli_answers&.delete('cluster_type'))
            else
              Type.find(
                cli_answers&.delete('cluster_type'),
                Config.cluster_type
              )
            end
          else
            if @options.reset_type
              Type.find(ask_for_cluster_type)
            else
              Type.find(Config.cluster_type || ask_for_cluster_type)
            end
          end
      end

      def ask_for_cluster_type
        prompt.select('Cluster type: ', Type.all.map { |t| t.name })
      end
    end
  end
end
