require_relative '../command'
require_relative '../config'
require_relative '../table'
require_relative '../node'
module Profile
  module Commands
    class Dequeue < Command
      def run

        strings = args[0].split(',')
        names = []
        strings.each do |str|
          names.append(expand_brackets(str))
        end

        names.flatten!

        failed = []
        names.each do |name|
          node_file = File.join(Config.queue_dir, name)
          if File.exists?(node_file)
            File.delete(node_file)
          else
            failed << name
          end
        end
        raise "The following nodes were not found in the queue: #{failed.join(', ')}" unless failed.empty?

        private

        def expand_brackets(str)
          contents = str[/\[.*\]/]
          return [str] if contents.nil?

          left = str[/[^\[]*/]
          right = str[/].*/][1..-1]

          unless contents.match(/^\[[0-9]+-[0-9]+\]$/)
            raise "Invalid range, ensure any range used is of the form [START-END]"
          end

          nums = contents[1..-2].split("-")

          unless nums.first.to_i < nums.last.to_i
            raise "Invalid range, ensure that the end index is greater than the start index"
          end

          (nums.first..nums.last).map do |index|
            left + index + right
          end
        end
      end
    end
  end
end
