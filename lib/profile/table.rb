require 'tty-table'

module Profile
  class Table
    def initialize
      @table = TTY::Table.new(header: [''])
      @table.header.fields.clear
      @padding = [0,1]
    end

    def emit
      puts @table.render(
        :unicode,
        {}.tap do |o|
          o[:padding] = @padding unless @padding.nil?
          o[:multiline] = true
        end
      )
    end

    def padding(*pads)
      @padding = pads.length == 1 ? pads.first : pads
    end

    # Each of `headers` and `rows` should be called like:
    # table.headers('First', 'Second')
    #
    # The `*args` argument uses the splat operator (*), which takes
    # all arguments passed to the method and squashes them into a 
    # single array. The above method call would expose the array
    # `titles` to the body of `headers`, with the contents:
    # `['First', 'Second']

    def headers(*titles)
      titles.each_with_index do |title, i|
        @table.header[i] = title
      end
    end

    # Add single row from single array
    def row(*vals)
      @table << vals
    end
    
    # Add multiple rows from nested array
    def rows(*vals)
      vals.each do |r|
        @table << r
      end
    end
  end
end
