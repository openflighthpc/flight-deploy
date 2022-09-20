require_relative '../command'

module Profile
  module Commands
    class Prepare < Command
      def run
        # ARGS:
        # [ type_id ]

        cluster_type = Type.find(args[0]) || Type.find(Config.cluster_type)
        raise "Cluster type not found" unless cluster_type

        raise "Cluster type is already prepared." if cluster_type.prepared?
        puts "Preparing '#{cluster_type.name}' cluster type..."
        if cluster_type.prepare
          puts "'#{cluster_type.name}' prepared."
          cluster_type.verify
        else
          raise "Error occurred while preparing. Please check the log for more details."
        end
      end
    end
  end
end
