require_relative '../command'

module Profile
  module Commands
    class Prepare < Command
      def run
        # ARGS:
        # [ type_id ]

        cluster_type = Type.find(args[0]) || Type.find(Config.cluster_type)
        raise "Cluster type not found" unless cluster_type

        puts "Preparing '#{cluster_type.name}' cluster type..."
        cluster_type.prepare
        puts "'#{cluster_type.name}' prepared."
      end
    end
  end
end
