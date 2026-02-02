module ApplicationHelperPatch
  def self.included(base)
    base.class_eval do

      # Split text into chunks on blank lines, but keep code blocks and macros together
      def split_into_chunks(text)
        chunks = []
        current_chunk = []
        in_code_fence = false
        in_macro = false
        
        text.lines.each do |line|
          # Track code fences
          in_code_fence = !in_code_fence if line =~ /^```/
          
          # Track macros
          in_macro = true if line =~ /\{\{/
          in_macro = false if line =~ /\}\}/
          
          # Split on blank lines only when not in code fence or macro
          if line.strip.empty? && !in_code_fence && !in_macro && current_chunk.any?
            chunks << current_chunk.join
            current_chunk = []
          else
            current_chunk << line
          end
        end
        
        chunks << current_chunk.join if current_chunk.any?
        chunks.reject { |c| c.strip.empty? }
      end

      # Detect format for a single chunk of text
      def detect_chunk_format(text)
        # Check for strong Markdown-only indicators first
        return 'common_mark' if text =~ /^```/m                      # Code fence
        return 'common_mark' if text =~ /\!\[[^\]]*\]\([^\)]+\)/     # Markdown image ![](url)
        return 'common_mark' if text =~ /^\#{1,6}\s+/m               # Markdown heading
        
        # Check for strong Textile-only indicators
        return 'textile' if text =~ /^\s*h[1-6]\.\s/m                # Textile heading h1.
        return 'textile' if text =~ /![\w\/\.\-]+!/                  # Textile image !url!
        return 'textile' if text =~ /\{\{/                           # Textile macro
        return 'textile' if text =~ /%\{[^}]+\}/                     # Textile inline style
        return 'textile' if text =~ /"[^"]+":(?:https?:\/\/|\/)/     # Textile link
        return 'textile' if text =~ /<pre[^>]*>/                     # HTML pre tag
        return 'textile' if text =~ /^\s*bc\.\s/m                    # Textile code block
        
        # Default to textile for ambiguous content
        'textile'
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