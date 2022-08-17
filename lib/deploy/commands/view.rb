require_relative '../command'

module Deploy
  module Commands
    class View < Command
      def run
        @hostname = args[0]
        puts "\nRunning:"
        display_command
        puts "\nProgress:"
        display_task_status
      end

      def display_command
        puts "   ansible-playbook -i #{Config.config.cluster_name}.inv --limit #{@hostname} openflight.yml"
      end

      def display_task_status
        task_name, task_status, role, new_role = nil
        roles = []
        @success = true
        log_file = File.open(node.log_filepath)
        log_file.readlines.each do |line|
          next if line.start_with?('PLAY')
          if line.start_with?('TASK')
            task = line[ /\[(.*?)\]/, 1 ].split(' : ')
            role = task.first
            task_name = task.last
            new_role = !roles.include?(role)
            roles << role if new_role
          elsif line.length > 1
            if task_name && (!task_status || success_statuses.include?(task_status))
              task_status = line.split(':')
                                .first
            end
          else
            if task_name && task_status
              puts role if new_role
              if success_statuses.include?(task_status)
                puts "   \u2705 #{task_name}"
              elsif fail_statuses.include?(task_status)
                puts "   \u274c #{task_name}"
                @success = false
              end
            end
            task_name, task_status = nil
          end
        end
      end

      def node
        @node ||= Node.find(@hostname)
      end

      def success_statuses
        %w[ok changed rescued]
      end

      def fail_statuses
        %w[failed fatal unreachable]
      end
    end
  end
end
