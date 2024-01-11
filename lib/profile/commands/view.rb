require 'curses'
require 'time'

require_relative '../command'

module Profile
  module Commands
    class View < Command
      def run
        @name = args[0]

        # load in node to raise error before starting curses
        node

        if @options.watch
          in_clean_window do
            loop do
              height = `tput lines`.chomp.to_i
              width = `tput cols`.chomp.to_i

              Curses.noecho
              Curses.curs_set(0)
              Curses.setpos(0, 0)

              truncated = output.lines.map do |line|
                [].tap do |out|
                  (line.length.to_f / width).ceil.times do |i|
                    out << line[0+(width*i)...width*(i+1)]
                  end
                end
              end.flatten

              Curses.clear
              Curses.addstr(truncated.last(height).join)
              Curses.refresh
              sleep 2
            end
          end
        else
          puts output
        end
      end

      private

      def use_hunter?
        Config.use_hunter?
      end

      def output
        return <<~OUT.chomp if node.status == 'available'
          Node '#{node.name}' is available. You can apply an identity to it with 'flight profile apply #{node.name} <identity>'.
        OUT

        return <<~OUT.chomp if node.status == 'queued'
          Node '#{node.name}' is queued for application awaiting its dependencies.
        OUT

        log = File.read(node.log_file)
        commands = log.split(/(?=PROFILE_COMMAND)/)
        "".tap do |output|
          commands.each do|cmd|
            status = cmd == commands.last ? nil : 'COMPLETE'
            output << "#{command_structure(cmd, status: status)}\n"
          end
        end
      end

      def in_clean_window
        Curses.init_screen
        begin
          yield
        ensure
          Curses.close_screen
        end
      end

      def command_structure(command, status: nil)
        header = command.split("\n").first.sub /^PROFILE_COMMAND .*: /, ''
        cmd_name = command[/(?<=PROFILE_COMMAND ).*?(?=:)/]
        <<~HEREDOC
          Command:
              #{cmd_name}

          Running:
              #{header}

          Progress:
          #{display_task_status(command).chomp}

          Status:
              #{status || node.status.upcase}

        HEREDOC
      end

      def node
        # attempt to find without hunter integration first to save time
        attempts = [
          -> { Node.find(@name, reload: true) },
          -> { Node.find(@name, reload: true, include_hunter: use_hunter?) }
        ]

        # Use Enumerable#lazy to return first truthy block result
        attempts.lazy.map(&:call).reject(&:nil?).first.tap do |n|
          raise "Node '#{@name}' not found" unless n
        end
      end

      class Task
        SUCCESS_STATUSES = %w[ok changed rescued].freeze
        FAIL_STATUSES = %w[failed fatal unreachable].freeze
        SKIP_STATUSES = %w[skipped ignored ok].freeze
        DONE_STATUSES = SUCCESS_STATUSES + FAIL_STATUSES + SKIP_STATUSES

        def initialize(name, steps)
          @name = name
          @steps = steps
        end

        attr_reader :name, :steps

        def success?
          status_in?(SUCCESS_STATUSES)
        end

        def failure?
          status_in?(FAIL_STATUSES)
        end

        def skipped?
          status_in?(SKIP_STATUSES)
        end

        def status_in?(arr)
          steps.any? { |s| arr.include?(s['category'].downcase) }
        end

        def in_progress?
          !success? && !failure? && !skipped?
        end

        def runtime
          in_progress? ? (Time.now - start_time).round(2) : (end_time - start_time).to_i
        end

        def start_time
          Time.parse(@steps.first['time'])
        end

        def end_time
          Time.parse(@steps.last['time'])
        end
      end

      def split_log_line(line)
        parts =
          line.split("\n")
            .map { |l| l.split(' - ') }
            .reject(&:empty?)
            .first

        keys = %w[time playbook task_role task_name task_action category data]
        keys.zip(parts).to_h.merge({ 'raw' => "#{line}\n" })
      end

      def display_task_status(command)
        str = ''

        tasks = command.lines[1..]
                       .map(&:chomp)
                       .reject(&:empty?)
                       .map { |l| split_log_line(l) }
                       .reject { |l| l['category'] == 'omitted' }
                       .group_by { |l| l['task_name'] }

        tasks = tasks.map { |name, steps| Task.new(name, steps) }

        tasks.each do |task|
          if @options.raw
            task.steps.each { |s| str += s['raw'] }
          elsif task.success?
            str += "   \u2705 #{task.name} (done in #{format_time(task.runtime)}s)\n"
          elsif task.failure?
            str += "   \u274c #{task.name} (done in #{format_time(task.runtime)}s)\n"
          elsif task.in_progress?
            str += "   \u231b #{task.name} (#{task.runtime} seconds elapsed)\n"
          end
        end
        str
      end

      def format_time(time)
        time < 1 ? '<1' : time
      end
    end
  end
end
