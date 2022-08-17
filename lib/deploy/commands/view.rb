require_relative '../command'

module Deploy
  module Commands
    class View < Command
      def run
        @hostname = args[0]
        raise "Setup has not been run for this node." unless node.log_filepath
        puts "\nRunning:"
        puts "   #{node.command}"
        puts "\nProgress:"
        display_task_status
        puts "\nStatus:"
        puts "   #{node.status.upcase}"
        puts "\n"
      end

      def node
        @node ||= Node.find(@hostname)
      end

      def display_task_status
        task_name, task_status, role, new_role = nil
        roles = []
        node.log_file.readlines.each do |line|
          if @options.raw
            puts line unless line == node.command
          else
            if line.start_with?('TASK')
              role, task_name = line[ /\[(.*?)\]/, 1 ].split(' : ')
              new_role = !roles.include?(role)
              roles << role if new_role
            elsif all_statuses.any? { |s| line.start_with?(s) }
              if !task_status || success_statuses.include?(task_status)
                task_status = line.split(':')
                                  .first
              end
            elsif task_name && task_status
              puts role if new_role
              if success_statuses.include?(task_status)
                puts "   \u2705 #{task_name}"
              elsif fail_statuses.include?(task_status)
                puts "   \u274c #{task_name}"
              end
              task_name, task_status = nil
            end
          end
        end
      end

      def success_statuses
        %w[ok changed rescued]
      end

      def fail_statuses
        %w[failed fatal unreachable]
      end

      def skip_statuses
        %w[skipped ignored]
      end

      def all_statuses
        success_statuses + fail_statuses + skip_statuses
      end
    end
  end
end
