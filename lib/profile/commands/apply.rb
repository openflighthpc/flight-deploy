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
        # [ names, identity ]
        # OPTS:
        # [ force ]
        @hunter = Config.use_hunter?

        names = args[0].split(',')

        # If using hunter, check to see if node actually exists
        check_nodes_exist(names) if @hunter

        # Don't let the user apply to a node that already has a profile
        disallow_existing_nodes(names)

        # Fetch cluster type
        cluster_type = Type.find(Config.cluster_type)
        raise "Invalid cluster type. Please run `profile configure`" unless cluster_type
        unless cluster_type.prepared?
          raise "Cluster type has not been prepared yet. Please run `profile prepare #{cluster_type.id}`."
        end

        # Check all questions have been answered
        missing_questions = cluster_type.questions.select { |q| !cluster_type.fetch_answer(q.id) }
        if missing_questions.any?
          q_names = missing_questions.map { |q| smart_downcase(q.text.delete(':')) }
          out = <<~OUT
          The following config keys have not been set:
          #{q_names.join("\n")}
          Please run `profile configure`
          OUT
          raise out
        end
        
        # Fetch identity
        unless @options.auto
          identity = cluster_type.find_identity(args[1])
          raise "No identity exists with given name" if !identity
          cmds = identity.commands

          #
          # ERROR CHECKING OVER; GOOD TO START APPLYING
          #

          hosts_term = names.length > 1 ? 'hosts' : 'host'
          printable_names = names.map { |h| "'#{h}'" }
          puts "Applying '#{identity.name}' to #{hosts_term} #{printable_names.join(', ')}"

          inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
          inventory.groups[identity.group_name] ||= []
          inv_file = inventory.filepath

          env = {
            "ANSIBLE_DISPLAY_SKIPPED_HOSTS" => "false",
            "ANSIBLE_HOST_KEY_CHECKING" => "false",
            "INVFILE" => inv_file,
            "RUN_ENV" => cluster_type.run_env
          }.tap do |e|
            cluster_type.questions.each do |q|
              e[q.env] = cluster_type.fetch_answer(q.id).to_s
            end
          end
        end

        names.each do |name|
        
          if @options.auto
            identity = nil
            Node.find(name, include_hunter: true).groups.each do |group|
              identity = cluster_type.find_identity(group)
              if identity
                cmds = identity.commands
                break
              end
            end

            if !identity
              puts "Skipping '#{name}' as none of its groups match a valid identity type"
              next
            end

            puts "Applying '#{identity.name}' to host #{name}"

            inventory = Inventory.load(Type.find(Config.cluster_type).fetch_answer("cluster_name"))
            inventory.groups[identity.group_name] ||= []
            inv_file = inventory.filepath

            env = {
              "ANSIBLE_DISPLAY_SKIPPED_HOSTS" => "false",
              "ANSIBLE_HOST_KEY_CHECKING" => "false",
              "INVFILE" => inv_file,
              "RUN_ENV" => cluster_type.run_env
            }.tap do |e|
              cluster_type.questions.each do |q|
                e[q.env] = cluster_type.fetch_answer(q.id).to_s
              end
            end
          end
          
          if @hunter
            hostname = Node.find(name, include_hunter: true).hostname
            ip = Node.find(name, include_hunter: true).ip
          else
            hostname = name
            ip = nil
          end

          node = Node.new(
            hostname: hostname,
            name: name,
            identity: identity.name,
            hunter_label: Node.find(name, include_hunter: true)&.hunter_label,
            ip: ip
          )

          if @hunter
            inv_row = "#{node.hostname} ansible_host=#{node.ip}"
          else
            inv_row = "#{node.hostname}"
          end
          inventory.groups[identity.group_name] |= [inv_row]
          inventory.dump

          pid = Process.fork do
            log_name = "#{Config.log_dir}/#{node.name}-#{Time.now.to_i}.log"

            last_exit = cmds.each do |command|
              sub_pid = Process.spawn(
                env.merge( { "NODE" => node.hostname} ),
                "echo PROFILE_COMMAND #{command[:name]}: #{command[:value]}; #{command[:value]}",
                [:out, :err] => [log_name, "a+"],
              )
              Process.wait(sub_pid)
              exit_status = $?.exitstatus

              if exit_status != 0
                break exit_status
              end

              if command == cmds.last && exit_status == 0
                break exit_status
              end
            end
            node.update(deployment_pid: nil, exit_status: last_exit)
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

      private

      def disallow_existing_nodes(names=[])
        existing = [].tap do |e|
          names.each do |name|
            node = Node.find(name, include_hunter: @hunter)
            e << name if node&.identity
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
      end

      def check_nodes_exist(names=[])
        not_found = names.select { |n| !Node.find(n, include_hunter: true) }
        if not_found.any?
          out = <<~OUT
          The following nodes were not found in Profile or Hunter:
          #{not_found.join("\n")}
          OUT
          raise out
        end
      end
    end
  end
end
