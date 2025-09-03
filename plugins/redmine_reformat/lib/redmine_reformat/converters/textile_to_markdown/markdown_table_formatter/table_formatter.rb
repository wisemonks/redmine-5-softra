module RedmineReformat
  module Converters
    module TextileToMarkdown
      module MarkdownTableFormatter

        class TableFormatter
          def initialize(string, header=true)
            @doc = string
            @header = header
          end

          # converts the markdown string into an array of arrays
          def parse
            @table = []
            rows = @doc.split /\r?\n/
            rows.each do |row|
              row_array = row.scan(/((?:[^\\|]|\\.)*)([|]|\z)/m).collect do |cell, sep|
                cell unless cell.empty? && sep.empty?
              end.compact
              row_array.each { |cell| cell.strip! }
              @table.push row_array
            end
            @table.delete_at(1) if @header #strip header separator
            @table
          end

          def table
            @table ||= parse
          end

          def column_width(column)
            width = 0
            table.each do |row|
              length = row[column].strip.length
              width = length if length > width
            end
            width
          end

          def pad(string,length)
            string.strip.ljust(length, ' ')
          end

          def separator(length)
            "".ljust(length,'-')
          end

          def header_separator_row
            output = []
            [*0...table.first.length].each do |column|
              output.push separator(column_width(column))
            end
            output
          end

          def to_md
            output = ""
            t = table.clone
            t.insert(1, header_separator_row) if @header
            t.each_with_index do |row, index|
              row.map!.with_index { |cell, index| cell = pad(cell, column_width(index)) }
              output += "#{row.join(" | ").lstrip} |\n"
            end
            output
          end
        end
      end
    end
  end
end
