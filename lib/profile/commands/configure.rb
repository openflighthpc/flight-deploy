require 'tty-prompt'
require 'yaml'
require 'json'
require 'bcrypt'
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
        cli_answers.tap do |a|
          if @options.accept_defaults
            generate_prefills(question)
            cluster_type.recursive_questions.each do |question|
              a[question.id] ||= @prefills[question.id] unless @prefills[question.id].nil?
            end
          end
          given = a&.keys || []
          required = required_cli_answers(a)
          if !(required - given).empty?
            raise "The following questions were not answered by the JSON data: #{(required - given).join(", ")}"
          elsif !(given - required).empty?
            raise "The following given answers are not recognised by the cluster type: #{(given - required).join(", ")}"
          end
        end
      end

      def required_cli_answers(given_answers, questions = cluster_type.questions, parent_answer = nil)
        [].tap do |required|
          questions.each do |q|
            if parent_answer.nil? || parent_answer == q.where
              required << q.id 
              required.concat(required_cli_answers(given_answers, q.questions, given_answers[q.id])) if q.questions
            end
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

      # recursively collect answers, the following is the example of the result
      def collect_answers(questions, parent_answer = nil)
        {}.tap do |ans|
          questions.each do |question|
            sleep(0.25) until @prefills && @prefills[question.id]
            if parent_answer.nil? || parent_answer == question.where
              # conditional question
              if question.type == "conditional"
                ans[question.id] = prompt.yes?(question.text) do |q|
                  q.default @prefills[question.id]
                  q.required question.validation.required
                end
              # password questions
              elsif question.id == "default_password" || question.type == "password"
                password_answer = ""
                password_abbr = cluster_type.fetch_answer("default_password_abbr") || question.default
                password_prompt = "default_password: \e[33m(" + password_abbr + ")\e[0m "
                print password_prompt

                validation_prompt = "  \e[91;1mMinimum 4 Characters\e[0m\e[22D"
                valid = true
                #handle user input events
                $stdin.raw do |raw|
                  loop do
                    char = raw.getc
                    char_value = char.ord
                    case char_value
                    # user press ctrl + c
                    when 3
                      raise Interrupt
                    # user press enter 
                    when 13
                      # invalid password input
                      if !password_answer.empty? && password_answer.length < 4
                        valid = false
                        print "\r\e[K" + password_prompt + "*" * (password_answer.length - 1)
                        print password_answer[-1] + validation_prompt
                        next
                      end
                      # password not changed
                      if password_answer.empty?
                        # encrypt when the password is the default password. Otherwise, the prefill value should have already been encrypted
                        ans[question.id] = @prefills[question.id] == question.default ? BCrypt::Password.create(@prefills[question.id]) : @prefills[question.id]
                      # valid password input
                      else
                        ans[question.id] = BCrypt::Password.create(password_answer)
                        # keep the prefill as plain text if it is set to be the default password
                        ans[question.id + "_abbr"] = password_answer == question.default ? password_answer : password_answer[0] + "*" * (password_answer.length - 2) + password_answer[-1]
                      end
                      print "\r\e[Kdefault_password: "
                      print "\e[32m" + "*" * password_abbr.length + "\e[0m"
                      print "\n\r"
                      break
                    # user press backspace
                    when 8
                      password_answer.chop! unless password_answer.empty?
                      valid = true if password_answer.empty?
                      print "\r\e[K" + password_prompt
                      print "*" * (password_answer.length - 1) unless password_answer.empty?
                      print password_answer[-1]
                      print validation_prompt unless valid
                    # regular password character input
                    else
                      if char_value > 31
                        password_answer << char
                        valid = true if password_answer.length >= 4
                        print "\r\e[K" + password_prompt
                        print "*" * (password_answer.length - 1)
                        print password_answer[-1]
                        print validation_prompt unless valid
                      end
                    end
                  end
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
              ans.merge(collect_answers(question.questions, ans[question.id])) if question.questions
            end
          end
        end
      end


      def generate_prefills(questions)
        @prefills ||= {}
        questions.each do |question|
          smart_log = Logger.new(File.join(Config.log_dir, 'configure.log'))

          prefill = question.id == "default_password" ? cluster_type.fetch_answer("default_password_abbr") : cluster_type.fetch_answer(question.id)
          if question.default_smart && prefill.nil?
            process = Flight::Subprocess::Local.new(
              env: {},
              logger: smart_log,
              timeout: 5,
            )
            result = process.run(question.default_smart, nil)
            output = result.stdout.chomp
            if !result.success?
              smart_log.debug("Command '#{question.default_smart}' failed to run: #{result.stderr.dump}")
            elsif (!question.validation.has_key?(:format) || output.match(Regexp.new(question.validation.format)))
              prefill ||= output
            else
              smart_log.debug("Command result '#{output}' did not pass validation check for '#{question.text}'")
            end
          end
          @prefills[question.id] = prefill || question.default || ""
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
