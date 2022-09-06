require_relative '../command'
require_relative '../profile'

module Deploy
  module Commands
    class Profiles < Command
      def run
        if args[0]
          cluster_type = Type.find(args[0])
          raise "Invalid cluster type" unless cluster_type
        elsif Config.cluster_type
          cluster_type = Type.find(Config.cluster_type)
          raise "Invalid cluster type. Please run `deploy configure`" unless cluster_type
          puts "Displaying profiles for cluster type: #{cluster_type.name}"
        else
          raise "Cluster type has not been defined. Pass desired type as an argument or run `deploy configure`."
        end
        raise "No profiles to display" unless cluster_type.profiles.any?

        t = Table.new
        t.headers('Name', 'Description')
        cluster_type.profiles.each do |p|
          t.row( p.name, p.description )
        end
        t.emit
      end
    end
  end
end
