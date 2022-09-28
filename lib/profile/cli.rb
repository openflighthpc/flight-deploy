#!/usr/bin/env ruby

require_relative 'commands'

require 'commander'

module Profile
  module CLI
    PROGRAM_NAME = 'profile'

    # Basic Commander config
    extend Commander::CLI
    program :application, "Flight Profile"
    program :name, PROGRAM_NAME
    program :version, "0.0.4-rc1"
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

    command :avail do |c|
      cli_syntax(c)
      c.summary = "List available cluster types"
      c.action Commands, :avail
      c.description = "Show list of available cluster types"
    end

    command :identities do |c|
      cli_syntax(c, '[TYPE]')
      c.summary = "List identities for a given cluster type"
      c.action Commands, :identities
      c.description = <<EOF
Show list of identities by name and description for a given cluster type.

If no cluster type is given, identities will be shown for the type chosen 
during configuration.
EOF
    end

    command :apply do |c|
      cli_syntax(c, ['NODE[,NODE...]', 'IDENTITY'])
      c.summary = "Apply an identity to one or more nodes"
      c.action Commands, :apply
      c.description = <<EOF
Apply an identity to one or more nodes. To set up multiple nodes,
enter the nodes' hostnames separated by commas.
EOF
      c.slop.bool "--force", "Overwrite the identity for a node that has already been set up"
    end

    command :list do |c|
      cli_syntax(c)
      c.summary = "Display all node information"
      c.action Commands, :list
      c.description = "Display the configuration identity and status of each node."
      c.slop.bool "--include-hunter", "Include nodes found by Flight Hunter"
    end
    alias_command :ls, :list

    command :clean do |c|
      cli_syntax(c, '[NODE,NODE,...]')
      c.summary = "Remove data for nodes that failed setup"
      c.action Commands, :clean
      c.description = <<EOF
Remove one or more nodes that failed setup to prevent them from appearing 
in the output of `profile list`.

Specify a node to remove by passing the node's hostname as an optional 
parameter. To remove multiple nodes, enter the nodes' hostnames separated 
by commas. 

If no nodes are specified, data for all nodes that are marked as 'FAILED' 
will be removed.
EOF
    end

    command :prepare do |c|
      cli_syntax(c, 'TYPE')
      c.summary = "Prepare dependencies for cluster type"
      c.action Commands, :prepare
      c.description =  <<EOF
Complete any required dependency steps for a given cluster type.

Specify a cluster type by passing the type's ID as a parameter.
If a cluster type is not given, the currently configured type
will be used. A type cannot be used until it has been prepared.
EOF
    end

    command :configure do |c|
      cli_syntax(c)
      c.summary = "Set the name and IP range of the cluster"
      c.action Commands, :configure
      c.description = "Set the cluster name and the IP range of your cluster nodes as an IPv4 CIDR block."
      c.slop.bool "--show", "Show the current configuration details."
    end

    command :view do |c|
      cli_syntax(c, 'NODE')
      c.summary = "View the setup status of a node"
      c.action Commands, :view
      c.description = "View the setup progress and status of a given node."
      c.slop.bool "--raw", "Show the entire ansible log output."
    end
  end
end
