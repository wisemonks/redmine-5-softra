module ApplicationHelperPatch
  def self.included(base)
    base.class_eval do

      # Split text into chunks based on blank lines and structural boundaries
      def split_into_chunks(text)
        chunks = []
        current_chunk = []
        in_code_block = false
        in_table = false
        code_fence_type = nil
        
        text.lines.each do |line|
          # Track code blocks (both markdown and textile)
          # Markdown fenced code blocks
          if line =~ /^```/
            if in_code_block && code_fence_type == :markdown
              in_code_block = false
              code_fence_type = nil
            elsif !in_code_block
              in_code_block = true
              code_fence_type = :markdown
            end
          # HTML pre/code tags
          elsif line =~ /<pre[^>]*>/ || line =~ /<code[^>]*>/
            in_code_block = true
            code_fence_type = :html
          elsif line =~ /<\/pre>/ || line =~ /<\/code>/
            in_code_block = false
            code_fence_type = nil
          # Textile code blocks
          elsif line =~ /^\s*bc\.\s/
            in_code_block = true
            code_fence_type = :textile
          elsif in_code_block && code_fence_type == :textile && line.strip.empty?
            in_code_block = false
            code_fence_type = nil
          end
          
          # Track tables (both markdown and HTML)
          if line =~ /^\s*\|.*\|/ || line =~ /<table[^>]*>/
            in_table = true
          elsif line =~ /<\/table>/
            in_table = false
          elsif in_table && line.strip.empty? && line !~ /^\s*\|/
            # End table on blank line without pipes
            in_table = false
          end
          
          # Split on blank lines, but keep code blocks and tables together
          if line.strip.empty? && !in_code_block && !in_table && current_chunk.any?
            chunks << current_chunk.join
            current_chunk = []
          else
            current_chunk << line
          end
        end
        
        # Add remaining chunk
        chunks << current_chunk.join if current_chunk.any?
        
        chunks
      end

      # Detect format for a single chunk of text
      def detect_chunk_format(text)
        # Regular expressions to match patterns specific to CommonMark (Markdown) and Textile
      
        # Strong Textile indicators (these are unique to Textile)
        textile_indicators = [
          /^\s*h[1-6]\.\s/m,           # Headings like h1., h2., h3.
          /"[^"]+":https?:\/\//,       # Links like "text":http://url
          /!\S+!/,                     # Images like !url!
          /^\s*\*\s+/m,                # Textile lists with *
          /^\s*#\s+/m,                 # Textile numbered lists with #
          /^\|[^\|]+\|/m,              # Tables with pipes
          /@\w+@/,                     # Textile code spans @code@
          /\*\*\w+\*\*/,               # Textile bold **text**
          /__\w+__/,                   # Textile italic __text__
        ]
        
        # Strong Markdown indicators (these are unique to Markdown)
        markdown_indicators = [
          /^\#{1,6}\s+/m,              # Markdown headings # ## ###
          /\!\[[^\]]*\]\([^\)]+\)/,    # Markdown images ![alt](url)
          /\[[^\]]+\]\([^\)]+\)/,      # Markdown links [text](url)
          /^```/m,                     # Markdown code fences
          /^\s*[-*+]\s+/m,             # Markdown unordered lists
          /^\s*\d+\.\s+/m,             # Markdown numbered lists
        ]
        
        # Count strong indicators for each format
        textile_score = textile_indicators.count { |pattern| text.match?(pattern) }
        markdown_score = markdown_indicators.count { |pattern| text.match?(pattern) }
        
        # Decide based on scores
        if textile_score > markdown_score
          'textile'
        elsif markdown_score > textile_score
          'common_mark'
        else
          # Default to common_mark if no clear winner
          'common_mark'
        end
      end
      
      # Render a chunk with the appropriate formatter
      def render_chunk(chunk, formatting, obj, attr)
        Redmine::WikiFormatting.to_html(formatting, chunk, :object => obj, :attribute => attr)
      end

      # Formats text according to system settings.
      # 2 ways to call this method:
      # * with a String: textilizable(text, options)
      # * with an object and one of its attribute: textilizable(issue, :description, options)
      def textilizable(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        case args.size
        when 1
          obj = options[:object]
          text = args.shift
        when 2
          obj = args.shift
          attr = args.shift
          text = obj.send(attr).to_s
        else
          raise ArgumentError, 'invalid arguments to textilizable'
        end
        return '' if text.blank?

        project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)
        @only_path = only_path = options.delete(:only_path) == false ? false : true

        text = text.dup

        if options[:formatting] == false
          text = h(text)
        else
          # Chunk-based formatting: split text and format each chunk independently
          chunks = split_into_chunks(text)
          
          formatted_chunks = chunks.map do |chunk|
            # Extract macros from this chunk
            chunk_macros = catch_macros(chunk)
            
            # Detect format for this specific chunk
            chunk_format = detect_chunk_format(chunk)
            
            # Render the chunk with its detected format
            rendered = render_chunk(chunk, chunk_format, obj, attr)
            
            # Process macros within this chunk's rendered output
            parse_non_pre_blocks(rendered, obj, chunk_macros, options) do |txt|
              [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
                send method_name, txt, project, obj, attr, only_path, options
              end
            end
          end
          
          # Join chunks - preserve original spacing
          text = formatted_chunks.join("\n\n")
        end

        @parsed_headings = []
        @heading_anchors = {}
        @current_section = 0 if options[:edit_section_links]

        parse_sections(text, project, obj, attr, only_path, options)
        parse_headings(text, project, obj, attr, only_path, options)

        if @parsed_headings.any?
          replace_toc(text, @parsed_headings)
        end

        text.html_safe
      end
    end
  end
end