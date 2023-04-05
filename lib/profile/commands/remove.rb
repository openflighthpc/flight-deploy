require_relative '../command'
require_relative '../config'
require_relative '../inventory'
require_relative '../node'
require_relative '../outputs'

require 'logger'

require 'open3'

module Profile
  module Commands
    class Remove < Command
      include Profile::Outputs
      def run
        # ARGS:
        # [ names ]

        names = args[0].split(',')

      end
    end
  end
end
