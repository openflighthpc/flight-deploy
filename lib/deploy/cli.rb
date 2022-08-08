#!/usr/bin/env ruby

require_relative 'commands'

require 'commander'

module Deploy
  module CLI
    PROGRAM_NAME = 'deploy'

    # Basic Commander config
    extend Commander::CLI
    program :application, "Flight Deploy"
    program :name, PROGRAM_NAME
    program :version, "0.0.1"
    program :description, "Manage automatic profiling of cluster nodes"
    program :help_paging, false
    default_command :help

    # Block to define methods as class methods,
    # equivalent to defining a method with `def self.method`
    class << self
      # Method to uniformly define a command's syntax.
      # Takes the command and the args string as arguments, and 
      # sets the command's syntax in the same way every time.
      def cli_syntax(command, args_str = nil)
        command.syntax = [
          PROGRAM_NAME,
          command.name,
          args_str
        ].compact.join(' ')
      end
    end

    # Commands go here:
    # command :example do |c|
    #   cli_syntax(c)
    #   c.summary = 'Do something useful'
    #   c.action Commands, :example
    #   c.description = ""
    # end
    # OPTIONAL: alias_command :something_else, :example
    #
    # NOTE: We are using a symbol object when specifying the command name
    # with `c.action`. We do this because it means we can refer to the
    # commands by name without having to import the class for every single
    # one in this file. We could also use a string, if we wanted to.
    # See Deploy::Commands::method_missing for more information.
  end
end
