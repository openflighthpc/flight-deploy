require_relative '../command'
require_relative '../identity'

module Profile
  module Commands
    class Identities < Command
      def run
        if args[0]
          cluster_type = Type.find(args[0])
          raise "Invalid cluster type" unless cluster_type
        elsif Config.cluster_type
          cluster_type = Type.find(Config.cluster_type)
          raise "Invalid cluster type. Please run `profile configure`" unless cluster_type
          puts "Displaying identities for cluster type: #{cluster_type.name}"
        else
          raise "Cluster type has not been defined. Pass desired type as an argument or run `profile configure`."
        end

        raise "No identities to display" unless cluster_type.identities.any?

        t = Table.new
        t.headers('Name', 'Description')
        cluster_type.identities.each do |p|
          t.row( p.name, p.description )
        end
        t.emit
      end
    end
  end
end
