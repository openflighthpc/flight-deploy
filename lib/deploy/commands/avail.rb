require_relative '../command'

module Deploy
  module Commands
    class Avail < Command
      def run
        puts "Hey"
      end
    end
  end
end