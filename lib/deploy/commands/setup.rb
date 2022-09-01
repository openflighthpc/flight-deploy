require_relative '../command'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Deploy
  module Commands
    class Setup < Command
      include Deploy::Outputs
      def run
        # ARGS:
        # [ hostname, profile ]
        # OPTS:
        # [ force ]

        hostnames = args[0].split(',')
        existing = [].tap do |e|
          hostnames.each do |name|
            node = Node.find(name)
            e << name if node && node.status != 'failed'
          end
        end

        unless existing.empty?
          existing_string = "The following nodes already have an applied profile: \n#{existing.join("\n")}"
          if @options.force
            say_warning existing_string + "\nContinuing..."
          else
            raise existing_string
          end
        end

        raise "A cluster type has not been chosen. Please run `deploy configure`" unless Config.cluster_type
        cluster_type = Type.find(Config.cluster_type)

        profile = cluster_type.find_profile(args[1])
        raise "No profile exists with given name" if !profile

        cluster_name = Config.config.cluster_name
        ip_range = Config.config.ip_range
        cmd = profile.command

        inventory = Inventory.load(cluster_name)
        inventory.groups[profile.group_name] ||= []
        inv_file = inventory.filepath

        hostnames.each do |hostname|

          node = Node.new(
            hostname: hostname,
            profile: args[1],
            )

          inventory.groups[profile.group_name] |= [node.hostname]
          inventory.dump

          pid = Process.fork do
            log_name = "#{Config.log_dir}/#{node.hostname}-#{Time.now.to_i}.log"
            sub_pid = Process.spawn(
              {
                "ANSIBLE_HOST_KEY_CHECKING" => "false",
                "INVFILE" => inv_file,
                "CLUSTERNAME" => cluster_name,
                "IPRANGE" => ip_range,
                "NODE" => node.hostname
              },
              "echo #{cmd}; #{cmd}",
              [:out, :err] => log_name,
              )
            Process.wait(sub_pid)
            # Storing the exit status of the sub-fork created by `Process.spawn`
            # so that we can judge if it passed or failed without having to
            # parse the Ansible logs
            node.update(deployment_pid: nil, exit_status: $?.exitstatus)

            if node.status == 'failed'
              inventory.remove_node(node, profile.group_name)
              failure = node.log_file
                            .readlines
                            .select { |line| line.start_with?('TASK') }
                            .last
              node.delete if failure.nil? || failure.include?('Waiting for nodes to be reachable')
            end
          end
          node.update(deployment_pid: pid) unless node.deleted
          Process.detach(pid)
        end
      end
    end
  end
end
