require 'tty-prompt'
require_relative '../command'

module Profile
  module Commands
    class Prepare < Command
      def run
        # ARGS:
        # [ type_id ]
        # OPTS:
        # [ reset_type ]

        if @options.reset_type
          cluster_type = Type.find(prompt.select('Cluster type: ', Type.all.map { |t| t.name }))
        else
          cluster_type = Type.find(args[0]) || Type.find(Config.cluster_type)
        end
        raise "Cluster type not found" unless cluster_type

        raise "Cluster type is already prepared." if cluster_type.prepared?
        puts "Preparing '#{cluster_type.name}' cluster type..."
        if cluster_type.prepare.success?
          puts "'#{cluster_type.name}' prepared."
          cluster_type.verify
        else
          raise "Error occurred while preparing. Please check the log for more details."
        end
      end

      private

      def prompt
        @prompt ||= TTY::Prompt.new(help_color: :yellow)
      end
    end
  end
end
