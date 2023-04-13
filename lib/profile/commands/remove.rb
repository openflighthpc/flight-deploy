require_relative '../command'
require_relative '../config'
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

        names = args[0].split(',')

        # Fetch cluster type
        cluster_type = Type.find(Config.cluster_type)
        raise "Invalid cluster type. Please run `profile configure`" unless cluster_type
        unless cluster_type.prepared?
          raise "Cluster type has not been prepared yet. Please run `profile prepare #{cluster_type.id}`."
        end

        # Check all questions have been answered
        unless cluster_type.configured?
          out = <<~OUT
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

        nodes.each do |node|
          log_file = "#{Config.log_dir}/#{node.name}-remove-#{Time.now.to_i}.log"

          pid = ProcessSpawner.run(
            node.fetch_identity.commands["remove"],
            log_file: log_file,
            env: env.merge({ "NODE" => node.hostname })
          ) do |last_exit|
            node.update(deployment_pid: nil, exit_status: last_exit)
            node.destroy if last_exit == 0
          end

          node.update(deployment_pid: pid)
          Process.detach(pid)
        end

        puts "The removal process has begun. Refer to `flight profile list` "\
             "or `flight profile view` for more details"
      end

      private

      def check_names_exist(names)
        not_found = names.select { |n| !Node.find(n)&.identity }
        if not_found.any?
          out = <<~OUT
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
          out = <<~OUT
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
          out = <<~OUT
          The following nodes are either in a failed process state
          or are currently undergoing a remove/apply process:
          #{busy.map(&:name).join("\n")}
          OUT
          raise out
        end
      end
    end
  end
end
