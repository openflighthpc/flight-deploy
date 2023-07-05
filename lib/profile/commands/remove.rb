require_relative '../command'
require_relative '../hunter_cli'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Remove < Command
      include Profile::Outputs

      def run
        # ARGS:
        # [ names ]
        # OPTS:
        # [ force ]
        @hunter = Config.use_hunter?

        strings = args[0].split(',')
        names = []
        strings.each do |str|
          names.append(expand_brackets(str))
        end

        names.flatten!

        # Fetch cluster type
        cluster_type = Type.find(Config.cluster_type)
        raise "Invalid cluster type. Please run `profile configure`" unless cluster_type
        unless cluster_type.prepared?
          raise "Cluster type has not been prepared yet. Please run `profile prepare #{cluster_type.id}`."
        end

        # Check all questions have been answered
        unless cluster_type.configured?
          out = <<~OUT.chomp
          Cluster type missing required configuration
          Please run `profile configure`
          OUT
          raise out
        end

        # Check nodes exist
        check_names_exist(names)

        nodes = names.map { |n| Node.find(n) }

        # Check nodes can be removed
        check_nodes_removable(nodes)

        # Check nodes can aren't in the middle of doing something else
        check_nodes_not_busy(nodes)

        hosts_term = names.length > 1 ? 'hosts' : 'host'
        printable_names = names.map { |h| "'#{h}'" }
        puts "Removing #{hosts_term} #{printable_names.join(', ')}"

        inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
        inv_file = inventory.filepath

        env = {
          "ANSIBLE_CALLBACK_PLUGINS" => Config.ansible_callback_dir,
          "ANSIBLE_STDOUT_CALLBACK" => "log_plays_v2",
          "ANSIBLE_DISPLAY_SKIPPED_HOSTS" => "false",
          "ANSIBLE_HOST_KEY_CHECKING" => "false",
          "INVFILE" => inv_file,
          "RUN_ENV" => cluster_type.run_env,
          "HUNTER_HOSTS" => @hunter.to_s
        }.tap do |e|
          cluster_type.questions.each do |q|
            e[q.env] = cluster_type.fetch_answer(q.id).to_s
          end
        end

        # Set up log files
        nodes.each do |node|
          ansible_log_path = File.join(
            ansible_log_dir,
            node.hostname
          )

          node.clear_logs
          log_symlink = "#{Config.log_dir}/#{node.name}-remove-#{Time.now.to_i}.log"

          FileUtils.mkdir_p(ansible_log_dir)
          FileUtils.touch(ansible_log_path)

          File.symlink(
            ansible_log_path,
            log_symlink
          )
        end

        # Group by identity to use different command for each
        nodes.group_by(&:identity).each do |identity, nodes|
          node_objs = Nodes.new(nodes)
          env = env.merge(
            {
              "NODE" => nodes.map(&:hostname).join(','),
              "ANSIBLE_LOG_FOLDER" => ansible_log_dir
            }
          )

          pid = ProcessSpawner.run(
            nodes.first.fetch_identity.commands["remove"],
            wait: @options.wait,
            env: env,
            log_files: nodes.map(&:log_filepath)
          ) do |last_exit|
            node_objs.update_all(deployment_pid: nil, exit_status: last_exit)

            node_objects.destroy_all if last_exit == 0
            if last_exit == 0 && @hunter && @options.remove_hunter_entry
              HunterCLI.remove_node(nodes.map(&:hunter_label).join(','))
            end
          end

          node_objs.update_all(deployment_pid: pid.to_i)
        end


        unless @options.wait
          puts "The removal process has begun. Refer to `flight profile list` "\
               "or `flight profile view` for more details"
        end

        # If `--wait` isn't included, the subprocesses are daemonised, and Ruby
        # will have no child processes to wait for, so this call ends
        # immediately. If `--wait` is included, the subprocesses aren't
        # daemonised, so the terminal holds IO until the process is finished.
        Process.waitall
      end

      private

      Nodes = Struct.new(:nodes) do
        def update_all(**kwargs)
          nodes.map { |node| node.update(**kwargs) }
        end
      end

      def ansible_log_dir
        @ansible_log_dir ||= File.join(
          Config.log_dir,
          'remove'
        )
      end

      def check_names_exist(names)
        not_found = names.select { |n| !Node.find(n)&.identity }
        if not_found.any?
          out = <<~OUT.chomp
          The following nodes either do not exist or
          do not have an identity applied to them:
          #{not_found.join("\n")}
          OUT
          raise out
        end
      end

      def check_nodes_removable(nodes)
        not_removable = nodes.select { |node| !node.fetch_identity.removable? }
        if not_removable.any?
          out = <<~OUT.chomp
          The following nodes have an identity that doesn't currently support
          the `profile remove` command:
          #{not_removable.map(&:name).join("\n")}
          OUT
          raise out
        end
      end

      def check_nodes_not_busy(nodes)
        busy = nodes.select { |node| node.status != 'complete' }
        if busy.any?
          existing_string = <<~OUT.chomp
          The following nodes are either in a failed process state
          or are currently undergoing a remove/apply process:
          #{busy.map(&:name).join("\n")}
          OUT

          if @options.force
            say_warning existing_string + "\nContinuing..."
            pids = busy.map(&:deployment_pid).compact
            pids.each { |pid| Process.kill("HUP", pid) }
          else
            raise existing_string
          end
        end
      end

      def expand_brackets(str)
        contents = str[/\[.*\]/]
        return [str] if contents.nil?

        left = str[/[^\[]*/]
        right = str[/].*/][1..-1]

        unless contents.match(/^\[[0-9]+-[0-9]+\]$/)
          raise "Invalid range, ensure any range used is of the form [START-END]"
        end

        nums = contents[1..-2].split("-")

        unless nums.first.to_i < nums.last.to_i
          raise "Invalid range, ensure that the end index is greater than the start index"
        end

        (nums.first..nums.last).map do |index|
          left + index + right
        end
      end
    end
  end
end
