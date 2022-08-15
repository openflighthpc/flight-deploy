require_relative 'commands/list'
require_relative 'commands/setup'
require_relative 'commands/configure'

module Deploy
  module Commands
    class << self
      def method_missing(s, *a, &b)
        # This overwrites the default Ruby behaviour for when a method is
        # called that is missing. If a command that the user called is "missing",
        # do some checks before throwing it away.
        if clazz = to_class(s)
          # This block is reached if a command is called with something other
          # than a class. You will notice that the command definitions in
          # Deploy::CLI are using symbols.
          # See if the argument used can be converted to a class,
          # and if it can, create a new instance and run it.
          clazz.new(*a).run!
        else
          # If the 'command' converted doesn't exist as a class,
          # then it truly is invalid.
          raise 'command not defined'
        end
      end

      def respond_to_missing?(s)
        # This is some Ruby magic that, when combined with #method_missing,
        # lets Ruby treat an "invalid" command as valid, if the #method_missing
        # check would return it as such.
        !!to_class(s)
      end

      private

      def to_class(s)
        # Interpret the given string and try and convert it to a class.
        s.to_s.split('-').reduce(self) do |clazz, p|
          p.gsub!(/_(.)./) { |a| a[1].upcase }
          clazz.const_get(p[0].upcase + p[1..-1])
        end
      rescue NameError
        nil
      end
    end
  end
end
