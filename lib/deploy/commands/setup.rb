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
        raise "Invalid cluster type. Please rerun `deploy configure`" unless cluster_type
        cluster_type.questions.each do |q|
          raise "The #{smart_downcase(q.text.delete(':'))} has not been defined. Please run `deploy configure`" unless Config.fetch(q.id)
        end

        profile = cluster_type.find_profile(args[1])
        raise "No profile exists with given name" if !profile
        cmd = profile.command

        cluster_type.prepare

        inventory = Inventory.load(Config.config.cluster_name || 'my-cluster')
        inventory.groups[profile.group_name] ||= []
        inv_file = inventory.filepath

        env = {
          "ANSIBLE_HOST_KEY_CHECKING" => "false",
          "INVFILE" => inv_file,
          "DEPLOYDIR" => Config.root,
        }.tap do |e|
          cluster_type.questions.each do |q|
            e[q.env] = Config.fetch(q.id)
          end
        end

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
              env.merge( {"NODE" => node.hostname} ),
              "echo #{cmd}; #{cmd}",
              [:out, :err] => log_name,
              )
            Process.wait(sub_pid)
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

      def smart_downcase(str)
        str.split.map do |word|
          /[A-Z]{2,}/.match(word) ? word : word.downcase
        end.join(' ')
      end
    end
  end
end
