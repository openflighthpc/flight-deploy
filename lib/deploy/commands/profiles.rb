require_relative '../command'
require_relative '../profile'

module Deploy
  module Commands
    class Profiles < Command
      def run
        raise "No profiles to display" if !Profile.all.any?

        Profile.all.each do |p|
          puts <<~PROFILE
          Name: #{p.name}
          Command: #{p.command}

          PROFILE
        end
      end
    end
  end
end
