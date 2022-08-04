#!/usr/bin/env ruby
require 'commander'

module Deploy
  module CLI
    extend Commander::CLI

    program :application, "Flight Deploy"
    program :name, "profile"
    program :version, "0.0.1"
    program :description, "Manage automatic profiling of cluster nodes"
    program :help_paging, false
    default_command :help

    if [/^xterm/, /rxvt/, /256color/].all? { |regex| ENV['TERM'] !~ regex }
      Paint.mode = 0
    end

    class << self
      def cli_syntax(command, args_str = nil)
        command.syntax = [
          PROGRAM_NAME,
          command.name,
          args_str
        ].compact.join(' ')
      end
    end

  end
end
