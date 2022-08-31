require_relative '../command'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'

require 'logger'

require 'open3'

module Deploy
  module Commands
    class Setup < Command
      def run
        # ARGS:
        # [ hostname, profile ]

        node = Node.find(args[0])
        raise "Node already exists" if node && node.status != 'failed'

        profile = Profile.find(args[1])
        raise "No profile exists with given name" if !profile

        node = Node.new(
          hostname: args[0],
          profile: args[1],
          deployment_pid: nil,
          exit_status: nil
        )

        cmd = profile.command
        cluster_name = Config.cluster_name
        ip_range = Config.ip_range

        raise "Deploy has not been configured yet" unless cluster_name && ip_range

        inventory = Inventory.load(cluster_name)
        # If profile doesn't exist in inventory, create it
        inventory.groups[profile.group_name] ||= []
        # Add node to profile if it isn't already there
        inventory.groups[profile.group_name] |= [node.hostname]
        inventory.dump

        inv_file = inventory.filepath

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
            node.delete if failure&.include?('Waiting for nodes to be reachable')
          end
        end
        node.update(deployment_pid: pid) if File.exist?(node.filepath)
        Process.detach(pid)
      end
    end
  end
end
