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
        raise "Node '#{@name}' not found" unless node

        if @options.watch
          in_clean_window do
            loop do
              height = `tput lines`.chomp.to_i
              print "\r\e[#{height}A"
              system("clear")
              puts output.lines.pop(height)
              sleep(0.5)
            end
          end
        else
          puts output
        end
      end

      def output
        log = File.read(node.log_file)
        commands = log.split(/(?=PROFILE_COMMAND)/)
        "".tap do |output|
          commands.each { |cmd| output << command_structure(cmd) + "\n" }
        end
      end
      
      def in_clean_window
        system "tput smcup"
        begin
          yield
        rescue Interrupt
          system "tput rmcup"
        end
      end

      def command_structure(command)
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
    #{node.status.upcase}

HEREDOC
      end

      def node
        Node.find(@name, reload: true)
      end

      def display_task_status(command)
        task_name, task_status, role, new_role = nil
        roles = []
        str = ""
        command.split("\n").each_with_index do |line, idx|
          line << "\n"
          if @options.raw
            str += line unless idx == 0
          else
            if line.start_with?('TASK')
              role, task_name = line[ /\[(.*?)\]/, 1 ].split(' : ')
              new_role = !roles.include?(role)
              roles << role if new_role
            elsif ALL_STATUSES.any? { |s| line.start_with?(s) }
              if !task_status || SUCCESS_STATUSES.include?(task_status)
                task_status = line.split(':')
                                  .first
              end
            elsif task_name && task_status
              str += "#{role}\n" if new_role
              if SUCCESS_STATUSES.include?(task_status)
                str += "   \u2705 #{task_name}\n"
              elsif FAIL_STATUSES.include?(task_status)
                str += "   \u274c #{task_name}\n"
              end
              task_name, task_status = nil
            end
          end
        end
        str
      end
    end
  end
end
