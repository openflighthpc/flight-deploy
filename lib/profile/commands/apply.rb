# frozen_string_literal: true

require_relative '../command'
require_relative './concerns/node_utils'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'
require_relative '../process_spawner'
require_relative '../queue_manager'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Apply < Command
      include Outputs
      include Concerns::NodeUtils

      def run
        # ARGS:
        # [ names, identity ]
        # OPTS:
        # [ wait, force, remove_on_shutdown, detect_identity, groups, dry_run ]
        @hunter = Config.use_hunter?
        @remove_on_shutdown = @options.remove_on_shutdown || Config.remove_on_shutdown
        raise 'The --detect-identity option requires use_hunter to be set' if @options.detect_identity && !@hunter

        raise 'Shared secret path not set or not valid!' if @remove_on_shutdown && !Config.shared_secret

        strings = args[0].split(',')
        names = []
        strings.each do |str|
          names.append(expand_brackets(str))
        end

        names.flatten!.uniq!

        # Reload all nodes
        nodes = Node.all(reload: true, include_hunter: @hunter)

        if @options.groups
          new_names = []
          nodes.each do |node|
            new_names << node.name if (node.groups & names).any?
          end
          raise 'No nodes found in the given group(s)' if new_names.empty?

          names = new_names
        end

        # If using hunter, check to see if node actually exists
        check_nodes_exist(names) if @hunter

        # Don't let the user apply to a node that already has a profile
        disallow_existing_nodes(names)

        # Check that any existing nodes aren't already busy
        check_nodes_not_busy(names)

        check_nodes_not_in_queue(names)

        # Fetch cluster type
        cluster_type = Type.find(Config.cluster_type)
        raise 'Invalid cluster type. Please run `profile configure`' unless cluster_type
        unless cluster_type.prepared?
          raise "Cluster type has not been prepared yet. Please run `profile prepare #{cluster_type.id}`."
        end

        answer_collection = collect_answers(cluster_type.questions, cluster_type.answers)
        answers = answer_collection['answers']
        # Check all questions have been answered
        missing_questions = answer_collection['missing_questions']
        if missing_questions.any?
          out = <<~OUT.chomp
            The following config keys have not been set:
            #{missing_questions.join("\n")}
            Please run `profile configure`
          OUT
          raise out
        end

        # Fetch identity
        unless args[1] || @options.detect_identity
          raise 'No identity given, use --detect-identity or specify an identity'
        end

        given_identity = cluster_type.find_identity(args[1])

        raise 'No identity exists with given name' unless given_identity || @options.detect_identity

        # Fetch existing nodes
        existing = Node.all(include_hunter: @hunter)

        # Construct new node objects
        new_nodes = Node.generate(names, given_identity&.name, include_hunter: @hunter,
                                                               detect_identity: @options.detect_identity)

        if @options.detect_identity
          missing_identity = new_nodes.select { |node| node.identity.nil? }.map(&:name)
          if missing_identity.any?
            raise <<~OUT
              Could not determine an identity for the following nodes: #{missing_identity.join(', ')}
              Either provide a default identity, or add an identity to their set of Hunter groups.
            OUT
          end
        end

        # Check for identity clashes
        total = existing + new_nodes

        new_nodes.each do |node|
          total.each do |existing|
            # Skip existing nodes without an identity (Hunter nodes)
            next unless existing.identity

            # Skip comparing conflicts with yourself, and skip comparing
            # conflicts with your potential corporeal counterpart. If a node
            # exists with the same name, it will be caught by
            # `disallow_existing_nodes`.
            next if existing.name == node.name

            node.errors << "clashes with '#{existing.name}'" if node.conflicts_with?(existing.identity)
          end

          Queue.index.each do |q, v|
            node.errors << "clashes with '#{q}'" if node.conflicts_with?(v[:identity])
          end
        end

        all_errors = new_nodes.map(&:full_errors).reject(&:empty?)

        if all_errors.any?
          raise <<~OUT.chomp
            There are identity conflicts to resolve:
            #{all_errors.join("\n")}
          OUT
        end

        if @options.dry_run
          new_nodes.group_by(&:identity).each do |identity, nodes|
            puts "'#{nodes.map(&:name).join("', '")}' would be applied with identity '#{identity}'"
          end
          return
        end

        # We've already got what we need from the given identity in this case
        given_identity = nil if @options.detect_identity

        to_queue = []
        new_nodes.each do |node|
          # Check for identity dependencies
          (total - [node]).select { |n| n.status == 'complete' }.tap do |existing|
            if node.dependencies.all? { |dep| existing.map(&:identity).include?(dep) }
              if !given_identity
                given_identity = node.fetch_identity
              elsif given_identity&.name != node.identity
                to_queue << node
              end
            else
              to_queue << node
            end
          end
        end

        # Check for nodes whose identities were determined to not match
        # the identity for the current apply process

        unless to_queue.empty?
          options = {
            'remove_on_shutdown' => @remove_on_shutdown,
            'force' => @options.force
          }

          to_queue.each do |node|
            QueueManager.push(node.name, node.identity, options: options)
            new_nodes.delete(node)
          end
          to_queue.group_by(&:identity).each do |identity, nodes|
            puts "Queueing '#{nodes.map(&:name).join("', '")}' for application of identity '#{identity}'"
          end
        end

        return unless new_nodes.any?

        #
        # ERROR CHECKING OVER; GOOD TO START APPLYING
        #

        hosts_term = new_nodes.length > 1 ? 'hosts' : 'host'
        printable_names = new_nodes.map { |n| "'#{n.name}'" }
        puts "Applying '#{given_identity.name}' to #{hosts_term} #{printable_names.join(', ')}"

        inventory.groups[given_identity.group_name] ||= []
        inv_file = inventory.filepath

        env = {
          'ANSIBLE_CALLBACK_PLUGINS' => File.join(Config.root, 'opt', 'ansible_callbacks'),
          'ANSIBLE_STDOUT_CALLBACK' => 'log_plays_v2',
          'ANSIBLE_DISPLAY_SKIPPED_HOSTS' => 'false',
          'ANSIBLE_HOST_KEY_CHECKING' => 'false',
          'INVFILE' => inv_file,
          'RUN_ENV' => cluster_type.run_env,
          'HUNTER_HOSTS' => @hunter.to_s
        }.merge(answers).transform_values(&:to_s)

        # Set up new nodes
        new_nodes.each do |node|
          inv_row = node.hostname.dup
          inv_row << " ansible_host=#{node.ip}" if @hunter

          inventory.groups[given_identity.group_name] |= [inv_row]
          node.clear_logs
          log_symlink = "#{Config.log_dir}/#{node.name}-apply-#{Time.now.to_i}.log"

          ansible_log_path = File.join(
            ansible_log_dir,
            node.hostname
          )

          FileUtils.mkdir_p(ansible_log_dir)
          FileUtils.touch(ansible_log_path)

          File.symlink(
            ansible_log_path,
            log_symlink
          )
        end

        inventory.dump

        env = env.merge(
          {
            'NODE' => new_nodes.map(&:hostname).join(','),
            'ANSIBLE_LOG_FOLDER' => ansible_log_dir
          }
        )

        node_objs = Nodes.new(new_nodes)

        cmds = given_identity.commands
        pid = ProcessSpawner.run(
          cmds['apply'],
          wait: @options.wait,
          env: env,
          log_files: new_nodes.map(&:log_filepath)
        ) do |last_exit|
          # ProcessSpawner yields the exit status of either:
          # - the first command to fail; or
          # - the final command
          # We yield it in a block so that the rest of the `apply`
          # logic can continue asynchronously.
          node_objs.update_all(deployment_pid: nil, exit_status: last_exit, last_action: nil)

          node_objs.each(&:install_remove_hook) if @remove_on_shutdown && last_exit.zero?
        end

        node_objs.update_all(deployment_pid: pid.to_i, last_action: 'apply')

        unless @options.wait
          puts 'The application process has begun. Refer to `flight profile list` '\
               'or `flight profile view` for more details'
        end

        # If `--wait` isn't included, the subprocesses are daemonised, and Ruby
        # will have no child processes to wait for, so this call ends
        # immediately. If `--wait` is included, the subprocesses aren't
        # daemonised, so the terminal holds IO until the process is finished.
        Process.waitall
      end

      def smart_downcase(str)
        str.split.map do |word|
          /[A-Z]{2,}/.match(word) ? word : word.downcase
        end.join(' ')
      end

      private

      def inventory
        @inventory ||= Inventory.load(Type.find(Config.cluster_type).fetch_answer('cluster_name'))
      end

      Nodes = Struct.new(:nodes) do
        def update_all(**kwargs)
          nodes.map { |node| node.update(**kwargs) }
        end

        def each(*args, **kwargs, &block)
          nodes.each(*args, **kwargs, &block)
        end

        def map(*args, **kwargs, &block)
          nodes.map(*args, **kwargs, &block)
        end
      end

      def ansible_log_dir
        @ansible_log_dir ||= File.join(
          Config.log_dir,
          'apply'
        )
      end

      def existing_nodes(names)
        existing = [].tap do |e|
          names.each do |name|
            node = Node.find(name)
            e << node if node&.identity
          end
        end
      end

      def disallow_existing_nodes(names)
        existing = existing_nodes(names)

        return if existing.empty?

        existing_string = <<~OUT.chomp
          The following nodes already have an applied identity:
          #{existing.map(&:name).join("\n")}
        OUT

        raise existing_string unless @options.force

        say_warning "#{existing_string}\nContinuing..."
      end

      def check_nodes_not_busy(names)
        existing = existing_nodes(names)
        busy = existing.select { |node| %w[removing applying].include?(node.status) }

        return if busy.empty?

        busy_string = <<~OUT.chomp
          The following nodes are currently undergoing another process:
          #{busy.map(&:name).join("\n")}
        OUT

        raise busy_string unless @options.force

        say_warning "#{busy_string}\nContinuing..."
        pids = busy.map(&:deployment_pid).compact
        pids.each { |pid| Process.kill('HUP', pid) }
      end

      def check_nodes_exist(names)
        not_found = names.reject { |n| Node.find(n, include_hunter: true) }
        return unless not_found.any?

        out = <<~OUT.chomp
          The following nodes were not found in Profile or Hunter:
          #{not_found.join("\n")}
        OUT
        raise out
      end

      def collect_answers(questions, answers, parent_answer = nil)
        {
          'answers' => {},
          'missing_questions' => []
        }.tap do |collection|
          questions.each do |question|
            next unless parent_answer.nil? || parent_answer == question.where
            if !answers[question.id].nil?
              collection['answers'][question.env] = answers[question.id]
            else
              collection['missing_questions'] << smart_downcase(question.text.delete(':'))
            end
            # collect the answers to the child questions
            if question.questions
              child_collection = collect_answers(question.questions, answers, answers[question.id])
              collection['answers'].merge!(child_collection['answers'])
              collection['missing_questions'].concat(child_collection['missing_questions'])
            end
          end
        end
      end
    end
  end
end
