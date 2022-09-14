require 'ostruct'

module Profile
  class Command
    attr_accessor :args, :options

    def initialize(args, options, command_name = nil)
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
