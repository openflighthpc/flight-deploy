require 'highline'

module Deploy
  module Outputs
    # A lot of this is copied from the `commander-rb/commander` upstream,
    # since `commander-openflighthpc was originally forked from an upstream
    # where the `Commander::UI` module didn't exist yet. If we ever update
    # our fork to include the new stuff, this module will become redundant.

    def say(*args)
      HighLine.default_instance.say(*args)
    end

    def say_warning(*args)
      args.each do |arg|
        say HighLine.default_instance.color(arg, :yellow)
      end
    end

    def say_error(*args)
      args.each do |arg|
        say HighLine.default_instance.color(arg, :red)
      end
    end

    ##
    # 'Say' something using the specified color
    #
    # === Examples
    #   color 'I am blue', :blue
    #   color 'I am bold', :bold
    #   color 'White on Red', :white, :on_red
    #
    # === Notes
    #   You may use:
    #   * color:    black blue cyan green magenta red white yellow
    #   * style:    blink bold clear underline
    #   * background: on_<color>

    def color(*args)
      say HighLine.default_instance.color(*args)
    end
  end
end
