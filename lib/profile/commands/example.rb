# Import command class so we can inherit from it later
require_relative '../command'

# `require_relative` imports a file specifically at the
# given file path, rather than `require` using the $LOAD_PATH

module Profile
  module Commands
    class Example < Command
      def run
        # Here goes what the command actually does when run
      end
    end
  end
end
