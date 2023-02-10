require_relative '../command'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Autoapply < Command
      include Profile::Outputs
      def run
        # ARGS:
        # [ names ]
        # OPTS:
        # [ force ]
        @hunter = Config.use_hunter?
        raise "use_hunter must be enabled to allow use of auto-apply" unless @hunter

        if args[0]
          names = args[0].split(',')
        else
          names = Node.all(include_hunter: true).map{ |n| n.name }
        end

        # Check to see if nodes actually exist
        check_nodes_exist(names)

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
        
        # Organise nodes into 2D priority array
        priority_sets = []
        nodes = names.map{ |name| Node.find(name, include_hunter: true) }
        nodes.each do |node|
          if @options.force || !existing(names).include?(node.name)
            identity = node.find_identity(cluster_type)
            if identity
              priority_sets[identity.priority] = priority_sets[identity.priority].to_a.append(node)
              puts "Applying '#{identity.name}' to host '#{node.name}'"
            else
              puts "No identity found for node '#{node.name}', skipping"
            end
          end
        end
        
        puts "The application process has begun. Refer to `flight profile list` "\
        "or `flight profile view` for more details"
        
        # Iterate through each set of same-priority nodes, applying them in parallel
        pid = Process.fork do
          priority_sets.each do |set|
            set.each do |node|
              identity = node.find_identity(cluster_type)
              node.apply_identity(identity, cluster_type)
            end
            statuses = set.map{ |node| node.status == "complete" }
            while !statuses.all?
              if statuses.include?("failed")
                raise "A node has failed to apply, aborting"
              end
              statuses = set.map{ |node| node.status == "complete" }
            end
          end
        end
      end

      def smart_downcase(str)
        str.split.map do |word|
          /[A-Z]{2,}/.match(word) ? word : word.downcase
        end.join(' ')
      end

      private

      def existing(names)
        [].tap do |e|
          names.each do |name|
            node = Node.find(name, include_hunter: @hunter)
            e << name if node&.identity_name
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
