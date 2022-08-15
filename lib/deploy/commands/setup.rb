require_relative '../command'
require_relative '../config'
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
        raise "Node already exists" if node

        node = Node.new(
          hostname: args[0],
          # Profile is currently only being set here. Work on 'profiles'
          # to actually use this value is planned to come later :tm:.
          profile: args[1],
          deployment_pid: nil,
          exit_status: nil
        )

        pid = Process.fork do
          log_name = "#{Config.log_dir}/#{node.hostname}-#{Time.now.to_i}.log"
          sub_pid = Process.spawn(
            { "ANSIBLE_HOST_KEY_CHECKING" => "false" },
            # Assuming that the user has passwordless sudo access
            "sudo ansible-playbook -i mycluster.inv openflight.yml",
            chdir: Config.ansible_dir,
            out: log_name,
            err: log_name
          )

          Process.wait(sub_pid)
          # Storing the exit status of the sub-fork created by `Process.spawn`
          # so that we can judge if it passed or failed without having to 
          # parse the Ansible logs
          node.update(deployment_pid: nil, exit_status: $?.exitstatus)
        end
        node.update(deployment_pid: pid)
        Process.detach(pid)
      end
    end
  end
end
