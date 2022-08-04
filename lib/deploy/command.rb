require 'ostruct'

module Deploy
  class Command
    attr_accessor :args, :options

    def initialize(args, options, command_name = nil)
      # Object#freeze prevents an object from being modified.
      # An error will be raised if modification is attempted.
      # This cannot be undone.
      @args = args.freeze
      @options = OpenStruct.new(options)
    end

    # This is for future error handling &/ logging
    def run!
      run
    end
    
    def run
      raise NotImplementedError
    end
  end
end
