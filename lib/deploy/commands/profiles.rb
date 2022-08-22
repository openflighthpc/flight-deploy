require_relative '../command'
require_relative '../profile'

module Deploy
  module Commands
    class Profiles < Command
      def run
        raise "No profiles to display" if !Profile.all.any?

        t = Table.new
        t.headers('Name', 'Description')
        Profile.all.each do |p|
          t.row( p.name, p.description )
        end
        t.emit
      end
    end
  end
end
