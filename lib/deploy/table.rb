require 'tty-table'

module Deploy
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

    def headers(*titles)
      titles.each_with_index do |title, i|
        @table.header[i] = title
      end
    end

    def padding(*pads)
      @padding = pads.length == 1 ? pads.first : pads
    end

    def row(*vals)
      @table << vals
    end
    
    def row(*vals)
      vals.each do |r|
        @table << r
      end
    end
  end
end
