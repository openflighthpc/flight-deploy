require 'curses'

require_relative '../command'

module Profile
  module Commands
    class View < Command
      SUCCESS_STATUSES = %w[ok changed rescued]
      FAIL_STATUSES = %w[failed fatal unreachable]
      SKIP_STATUSES = %w[skipped ignored]
      ALL_STATUSES = SUCCESS_STATUSES + FAIL_STATUSES + SKIP_STATUSES

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

        log = File.read(node.log_file)
        commands = log.split(/(?=PROFILE_COMMAND)/)
        "".tap do |output|
          commands.each do|cmd|
            status = cmd == commands.last ? nil : 'COMPLETE'
            output << command_structure(cmd, status: status) + "\n"
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
        <<HEREDOC
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
          lambda { Node.find(@name, reload: true) },
          lambda { Node.find(@name, reload: true, include_hunter: use_hunter?) }
        ]

        # Use Enumerable#lazy to return first truthy block result
        attempts.lazy.map(&:call).reject(&:nil?).first.tap do |n|
          raise "Node '#{@name}' not found" unless n
        end
      end

      def split_log_line(line)
        parts =
          line.split("\n")
            .map { |l| l.split(' - ') }
            .reject(&:empty?)
            .first

        keys = %w{time playbook task_role task_name task_action category data}
        keys.zip(parts).to_h
      end

      def display_task_status(command)
        new_role = nil
        roles = Hash.new(0)
        str = ""
        command.split("\n").each_with_index do |line, idx|
          line << "\n"
          if @options.raw
            str += line unless idx == 0
          else
            next if line.chomp.empty?
            next if line.include?("PROFILE_COMMAND")

            parts = split_log_line(line)

            next if parts['task_role'] == 'None'

            role = parts['task_role']
            new_role = !roles.key?(role)
            roles[role] += 1 unless parts['category'] == 'SKIPPED'
            str += "#{role}\n" if new_role && roles[role] > 0

            if SUCCESS_STATUSES.include?(parts['category']&.downcase)
              str += "   \u2705 #{parts['task_name']}\n"
            elsif FAIL_STATUSES.include?(parts['category']&.downcase)
              str += "   \u274c #{parts['task_name']}\n"
            end
          end
        end
        str
      end
    end
  end
end
