require_relative '../command'
require_relative '../profile'

module Deploy
  module Commands
    class Profiles < Command
      def run
        if args[0]
          cluster_type = args[0]
        elsif Config.cluster_type
          cluster_type = Config.cluster_type
          puts "Displaying profiles for cluster type: #{cluster_type}"
        else
          raise "Cluster type has not been defined. Pass desired type as an argument or run `configure`."
        end
        raise "No profiles to display" unless Profile.all(cluster_type).any?

        t = Table.new
        t.headers('Name', 'Description')
        Profile.all(cluster_type).each do |p|
          t.row( p.name, p.description )
        end
        t.emit
      end
    end
  end
end
