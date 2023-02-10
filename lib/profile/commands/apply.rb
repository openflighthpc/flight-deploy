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

        identity = cluster_type.find_identity(args[1])
        raise "No identity exists with given name" if !identity
        
        hosts_term = names.length > 1 ? 'hosts' : 'host'
        printable_names = names.map { |h| "'#{h}'" }
        puts "Applying '#{identity.name}' to #{hosts_term} #{printable_names.join(', ')}"
        
        names.each do |name|
          if @hunter
            node = Node.find(name, include_hunter: true)
          else
            node = Node.new(hostname: name)
          end

          node.identity_name = identity.name
          node.apply_identity(identity, cluster_type)
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
            e << name if node&.identity_name
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
