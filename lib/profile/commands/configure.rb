require 'tty-prompt'
require 'yaml'
require 'json'
require 'digest'
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
            cluster_type.questions.each do |question|
              prefill = generate_prefill(question)
              a[question.id] ||= prefill unless prefill.nil?
            end
          end
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
        smart_log = Logger.new(File.join(Config.log_dir, 'configure.log'))

        prefills = {}
        type.questions.each do |question|
          Thread.fork do
            prefills[question.id] = generate_prefill(question)
          end
        end
        password_answer, encrypted_password_answer, password_abbr = ''
        answer = prompt.collect do
          type.questions.each do |question|
            sleep(0.25) while !prefills[question.id]
            # password question handled manually
            if question.id == "default_password"
              password_abbr = type.fetch_answer("default_password_abbr") || question.default
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
                      encrypted_password_answer = prefills[question.id] == question.default ? Digest::SHA512.hexdigest(prefills[question.id]) : prefills[question.id]
                    # valid password input
                    else
                      encrypted_password_answer = Digest::SHA512.hexdigest(password_answer)
                      # keep the prefill as plain text if it is set to be the default password
                      password_abbr = password_answer == question.default ? password_answer : password_answer[0] + "*" * (password_answer.length - 2) + password_answer[-1]
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
            # other questions managed by tty prompt
            else
              key(question.id).ask(question.text) do |q|
                q.default prefills[question.id]
                q.required question.validation.required
                if question.validation.to_h.key?(:format)
                  q.validate Regexp.new(question.validation.format)
                  q.messages[:valid?] = question.validation.message
                end
              end
            end
          end
        end
        answer["default_password"] = encrypted_password_answer
        answer["default_password_abbr"] = password_abbr
        puts answer.inspect
        answer
      end

      def generate_prefill(question)
        smart_log = Logger.new(File.join(Config.log_dir, 'configure.log'))

        prefill = cluster_type.fetch_answer(question.id)
        if question.default_smart && prefill.nil?
          prefill ||= best_command_output(command_list: question.default_smart,
                                          log: smart_log,
                                          regex: question.validation&.has_key?(:format) ? question.validation.format : nil)
        end
        prefill ||= question.default || ""
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
        cluster_type.questions.each do |q|
          next unless q.validation.has_key?(:format)
          criterion = Regexp.new(q.validation.format)
          bad_answers << q.id unless answers[q.id].match(criterion)
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
