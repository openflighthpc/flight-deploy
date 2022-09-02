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

    command :profiles do |c|
      cli_syntax(c)
      c.summary = "List profiles"
      c.action Commands, :profiles
      c.description = "Show list of profiles by name and command"
    end

    command :setup do |c|
      cli_syntax(c, ['HOSTNAME[,HOSTNAME...]', 'PROFILE'])
      c.summary = "Set up one or more nodes with a given profile."
      c.action Commands, :setup
      c.description = <<EOF
Set up one or more nodes with a given profile. To set up multiple nodes,
enter the nodes' hostnames separated by commas.
EOF
      c.slop.bool "--force", "Overwrite the profile for a node that has already been set up"
    end

    command :list do |c|
      cli_syntax(c)
      c.summary = "Display all node information."
      c.action Commands, :list
      c.description = "Display the configuration profile and status of each node."
    end
    alias_command :ls, :list

    command :configure do |c|
      cli_syntax(c)
      c.summary = "Set the name and IP range of the cluster."
      c.action Commands, :configure
      c.description = "Set the cluster name and the IP range of your cluster nodes as an IPv4 CIDR block."
      c.slop.bool "--show", "Show the current configuration details."
    end

    command :view do |c|
      cli_syntax(c, 'NODE')
      c.summary = "View the setup status of a node."
      c.action Commands, :view
      c.description = "View the setup progress and status of a given node."
      c.slop.bool "--raw", "Show the entire ansible log output."
    end
  end
end
