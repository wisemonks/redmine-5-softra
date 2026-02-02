module ApplicationHelperPatch
  def self.included(base)
    base.class_eval do

      # Detect format of a single line
      def detect_line_format(line)
        # Strong Markdown-only patterns
        return 'common_mark' if line =~ /^```/                    # Code fence
        return 'common_mark' if line =~ /^\!\[.*\]\(.*\)/         # Markdown image
        return 'common_mark' if line =~ /^\#{1,6}\s+/             # Markdown heading
        return 'common_mark' if line =~ /^\s*[-+]\s+/             # Markdown list (- or +)
        
        # Strong Textile-only patterns
        return 'textile' if line =~ /^\s*h[1-6]\.\s/              # Textile heading
        return 'textile' if line =~ /^![\w\/\.\-]+!/              # Textile image
        return 'textile' if line =~ /^\s*bc\.\s/                  # Textile code block
        return 'textile' if line =~ /%\{[^}]+\}/                  # Textile inline style
        return 'textile' if line =~ /\{\{[^}]+\}\}/               # Textile macro
        return 'textile' if line =~ /"[^"]+":(?:https?:\/\/|\/)/  # Textile link
        
        # Default to textile for ambiguous content
        'textile'
      end
      
      # Split text into chunks based on format changes
      def split_into_chunks(text)
        chunks = []
        current_chunk = []
        current_format = nil
        in_code_fence = false
        
        text.lines.each do |line|
          # Track code fences
          if line =~ /^```/
            in_code_fence = !in_code_fence
          end
          
          # Detect format of this line
          line_format = detect_line_format(line)
          
          # If format changes and we're not in a code fence, start new chunk
          if current_format && line_format != current_format && !in_code_fence && line.strip != ''
            chunks << current_chunk.join if current_chunk.any?
            current_chunk = [line]
            current_format = line_format
          else
            current_chunk << line
            current_format ||= line_format
          end
        end
        
        # Add remaining chunk
        chunks << current_chunk.join if current_chunk.any?
        
        chunks.reject { |c| c.strip.empty? }
      end

      # Detect format for a single chunk of text
      def detect_chunk_format(text)
        # Regular expressions to match patterns specific to CommonMark (Markdown) and Textile
      
        # Strong Textile indicators (these are unique to Textile)
        textile_indicators = [
          /^\s*h[1-6]\.\s/m,                    # Headings like h1., h2., h3.
          /"[^"]+":(?:https?:\/\/|\/)/,         # Links like "text":http://url or "text":/path
          /![\w\/\.\-]+!/,                      # Images like !url! (not ![...] which is Markdown)
          /^\s*\*+\s+/m,                        # Textile lists with * or **
          /^\s*#+\s+/m,                         # Textile numbered lists with #
          /^\|[^\|]+\|/m,                       # Tables with pipes
          /@[^@\s]+@/,                          # Textile code spans @code@
          /\{\{[^}]+\}\}/m,                     # Textile macros {{macro(...)}}
          /\*\*[^\*]+\*\*/,                     # Textile bold **text**
          /__[^_]+__/,                          # Textile italic __text__
          /^\s*bc\.\s/m,                        # Textile code blocks bc.
          /attachment:/,                        # Redmine attachment syntax
          /^\s*----+\s*$/m,                     # Horizontal rules (common in Textile)
          /%\{[^}]+\}/,                         # Textile inline styles %{color:red}text%
        ]
        
        # Strong Markdown indicators (these are unique to Markdown)
        markdown_indicators = [
          /^\#{1,6}\s+/m,                       # Markdown headings # ## ###
          /\!\[[^\]]*\]\([^\)]+\)/,             # Markdown images ![alt](url)
          /\[[^\]]+\]\([^\)]+\)/,               # Markdown links [text](url)
          /^```/m,                              # Markdown code fences
          /^\s*[-+]\s+/m,                       # Markdown unordered lists (- or +, but not *)
          /^\s*\d+\.\s+/m,                      # Markdown numbered lists
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
          # Default to textile for Redmine compatibility
          'textile'
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
          # Check if we have mixed format content
          chunks = split_into_chunks(text)
          chunk_formats = chunks.map { |chunk| detect_chunk_format(chunk) }
          has_mixed_formats = chunk_formats.uniq.size > 1
          
          if has_mixed_formats && chunks.size > 1
            # Mixed formats - render each chunk with its own format
            formatted_chunks = chunks.map do |chunk|
              # Extract macros from this chunk
              chunk_macros = catch_macros(chunk)
              
              # Detect format for this specific chunk
              chunk_format = detect_chunk_format(chunk)
              
              # Render the chunk with its detected format
              rendered = Redmine::WikiFormatting.to_html(chunk_format, chunk, :object => obj, :attribute => attr)
              
              # Process macros within this chunk's rendered output
              parse_non_pre_blocks(rendered, obj, chunk_macros, options) do |txt|
                [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
                  send method_name, txt, project, obj, attr, only_path, options
                end
              end
            end
            
            # Join rendered HTML chunks directly (they already have proper HTML structure)
            text = formatted_chunks.join
          else
            # Single format - render entire text at once to preserve structure
            macros = catch_macros(text)
            formatting = detect_chunk_format(text)
            text = Redmine::WikiFormatting.to_html(formatting, text, :object => obj, :attribute => attr)
            
            text = parse_non_pre_blocks(text, obj, macros, options) do |txt|
              [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
                send method_name, txt, project, obj, attr, only_path, options
              end
            end
          end
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