require_relative '../command'
require_relative '../config'
require_relative '../node'

require 'logger'

require 'open3'

module Deploy
  module Commands
    class Setup < Command
      def run
        node = Node.find(args[0])
        raise "Node already exists" if node

        node = Node.new(
          hostname: args[0],
          profile: args[1],
          deployment_pid: nil,
          exit_status: nil
        )

        pid = Process.fork do
          sub_pid = Process.spawn(
            { "ANSIBLE_HOST_KEY_CHECKING" => "false" },
            "sudo ansible-playbook -i mycluster.inv openflight.yml",
            chdir: Config.ansible_dir
            out: "#{Config.log_dir}/#{node.hostname}-#{Time.now.to_i}.log"
          )

          Process.wait(sub_pid)
          node.update(deployment_pid: nil, exit_status: $?.exitstatus)
        end
        node.update(deployment_pid: pid)
        Process.detach(pid)
      end
    end
  end
end
