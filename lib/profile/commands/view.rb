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
        log = File.read(node.log_file)
        commands = log.split(/(?=PROFILE_COMMAND)/)
        commands.each { |cmd| puts command_structure(cmd) }
      end

      def command_structure(command)
        header = command.split("\n").first.sub /^PROFILE_COMMAND .*: /, ''
        cmd_name = command[/(?<=PROFILE_COMMAND ).*?(?=:)/]
        puts <<HEREDOC
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
        @node ||= Node.find(@name)
      end

      def display_task_status(command)
        task_name, task_status, role, new_role = nil
        roles = []
        str = ""
        command.split("\n").each_with_index do |line, idx|
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
