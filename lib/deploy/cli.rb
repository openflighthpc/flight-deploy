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

    command :setup do |c|
      cli_syntax(c, ['NODE', 'PROFILE'])
      c.summary = "Hard-coded Ansible deployment for testing"
      c.action Commands, :setup
      c.description = "Hard-coded Ansible deployment for testing"
    end

    command :list do |c|
      cli_syntax(c)
      c.summary = 'Display all node information.'
      c.action Commands, :list
      c.description = "Display the configuration profile and status of each node."
    end
    alias_command :ls, :list
  end
end
