require_relative '../command'

module Deploy
  module Commands
    class View < Command
      SUCCESS_STATUSES = %w[ok changed rescued]
      FAIL_STATUSES = %w[failed fatal unreachable]
      SKIP_STATUSES = %w[skipped ignored]
      ALL_STATUSES = SUCCESS_STATUSES + FAIL_STATUSES + SKIP_STATUSES

      def run
        @hostname = args[0]
        raise "Setup has not been run for this node." unless node.log_filepath
        puts <<HEREDOC

Running:
   #{node.command.chomp}

Progress:
#{display_task_status.chomp}

Status:
   #{node.status.upcase}

HEREDOC
      end

      def node
        @node ||= Node.find(@hostname)
      end

      def display_task_status
        task_name, task_status, role, new_role = nil
        roles = []
        str = ""
        node.log_file.readlines.each do |line|
          if @options.raw
            str += line unless line == node.command
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
