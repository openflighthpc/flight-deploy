require_relative '../command'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Apply < Command
      include Profile::Outputs
      def run
        # ARGS:
        # [ hostname, identity ]
        # OPTS:
        # [ force ]

        hostnames = args[0].split(',')
        existing = [].tap do |e|
          hostnames.each do |name|
            node = Node.find(name)
            e << name if node
          end
        end

        unless existing.empty?
          existing_string = "The following nodes already have an applied identity: \n#{existing.join("\n")}"
          if @options.force
            say_warning existing_string + "\nContinuing..."
          else
            raise existing_string
          end
        end

        raise "A cluster type has not been chosen. Please run `profile configure`" unless Config.cluster_type
        cluster_type = Type.find(Config.cluster_type)
        raise "Invalid cluster type. Please rerun `profile configure`" unless cluster_type
        cluster_type.questions.each do |q|
          raise "The #{smart_downcase(q.text.delete(':'))} has not been defined. Please run `profile configure`" unless Config.fetch(q.id)
        end

        identity = cluster_type.find_identity(args[1])
        raise "No identity exists with given name" if !identity
        cmd = identity.command

        host_term = hostnames.length > 1 ? 'hosts' : 'host'
        printable_hosts = hostnames.map { |h| "'#{h}'" }
        puts "Applying '#{identity.name}' to #{host_term} #{printable_hosts.join(', ')}"

        inventory = Inventory.load(Config.config.cluster_name || 'my-cluster')
        inventory.groups[identity.group_name] ||= []
        inv_file = inventory.filepath

        env = {
          "ANSIBLE_HOST_KEY_CHECKING" => "false",
          "INVFILE" => inv_file,
          "RUN_ENV" => cluster_type.run_env
        }.tap do |e|
          cluster_type.questions.each do |q|
            e[q.env] = Config.fetch(q.id)
          end
        end

        hostnames.each do |hostname|
          node = Node.new(
            hostname: hostname,
            identity: args[1],
            )

          inventory.groups[identity.group_name] |= [node.hostname]
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
          end
          node.update(deployment_pid: pid)
          Process.detach(pid)
        end

        puts "The application process has begun. Refer to `flight profile list` "\
             "or `flight profile view` for more details"
      end

      def smart_downcase(str)
        str.split.map do |word|
          /[A-Z]{2,}/.match(word) ? word : word.downcase
        end.join(' ')
      end
    end
  end
end
