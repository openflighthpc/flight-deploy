module Profile
  module Commands
    module Concerns
      module NodeUtils
        private

        def check_nodes_not_in_queue(names)
          in_queue = names.select { |n| QueueManager.contains?(n) }

          if in_queue.any?
            out = <<~OUT.chomp
            The following nodes are already queued:
            #{in_queue.join("\n")}
            OUT
            raise out
          end
        end

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
