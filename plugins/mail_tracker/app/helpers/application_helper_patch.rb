module ApplicationHelperPatch
  def self.included(base)
    base.class_eval do

      # Helper method to detect format from text
      # Checks for {{textile}} tag at the beginning, otherwise uses system default
      def detect_format(text)
        if text =~ /^\s*\{\{textile\}\}\s*\n?/i
          'textile'
        else
          Setting.text_formatting
        end
      end

      # Override textilizable to support {{textile}} tag at the beginning of text
      # If {{textile}} is present, use textile formatting regardless of system settings
      # Otherwise, use system default formatting (Setting.text_formatting)
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
        macros = catch_macros(text)

        if options[:formatting] == false
          text = h(text)
        else
          # Check for {{textile}} tag at the beginning
          if text =~ /^\s*\{\{textile\}\}\s*\n?/i
            formatting = 'textile'
            # Remove the tag from text
            text = text.sub(/^\s*\{\{textile\}\}\s*\n?/i, '')
          else
            # Use system default formatting
            formatting = Setting.text_formatting
          end
          
          text = Redmine::WikiFormatting.to_html(formatting, text, :object => obj, :attribute => attr)
        end

        @parsed_headings = []
        @heading_anchors = {}
        @current_section = 0 if options[:edit_section_links]

        parse_sections(text, project, obj, attr, only_path, options)
        text = parse_non_pre_blocks(text, obj, macros, options) do |txt|
          [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
            send method_name, txt, project, obj, attr, only_path, options
          end
        end
        parse_headings(text, project, obj, attr, only_path, options)

        if @parsed_headings.any?
          replace_toc(text, @parsed_headings)
        end

        text.html_safe
      end
    end
  end
end

# ==============================================================================
# OLD CUSTOM CODE - COMMENTED OUT FOR REFERENCE
# ==============================================================================
#
# # Resolve whether the text given is 'textile' or 'markdown'. Fall back to 'markdown' if the text is not recognized.
# def detect_format(text)
#   # Regular expressions to match patterns specific to CommonMark (Markdown) and Textile
# 
#   # Markdown patterns
#   markdown_patterns = [
#     # /^\#{1,6}\s/,  # Headings like #, ##, ###, etc.
#     /\[.*?\]\(.*?\)/, # Links like [text](url)
#     /\!\[.*?\]\(.*?\)/, # Images like ![alt text](url)
#     /<h\d>/,  # Headings like <h1>, <h2>, <h3>, etc.
#     /<strong>.*?<\/strong>/, # Bold text like <strong>bold</strong>
#     /<em>.*?<\/em>/,     # Italic text like <em>italic</em>
#     /<a.*?>.*?<\/a>/, # Links like <a href="url">text</a>
#     /<img.*?>/, # Images like <img src="url" alt="alt text">
#     /<table.*?>.*?<\/table>/, # Tables like <table>...</table>
#     /<ul>.*?<\/ul>/, # Unordered lists like <ul>...</ul>
#     /<ol>.*?<\/ol>/, # Ordered lists like <ol>...</ol>
#     /<li>.*?<\/li>/, # List items like <li>...</li>
#     /<code>.*?<\/code>/, # Code blocks like <code>...</code>
#     /<pre>.*?<\/pre>/, # Preformatted text like <pre>...</pre>
#     /<blockquote>.*?<\/blockquote>/, # Blockquotes like <blockquote>...</blockquote>
#     /<hr>/, # Horizontal rules like <hr>
#     /<br>/, # Line breaks like <br>
#     /<p>.*?<\/p>/, # Paragraphs like <p>...</p>
#     /<span.*?>.*?<\/span>/, # Spans like <span>...</span>
#     /<div.*?>.*?<\/div>/ # Divs like <div>...</div>
#   ]
# 
#   # Textile patterns
#   textile_patterns = [
#     /^\s*h\d\.\s/,  # Headings like h1., h2., h3., etc.
#     /".*?":http.*?/, # Links like "text":http://example.com
#     /!\[.*?\]:.*?|!\[.*?\]:.*?|!\[.*?\]!/, # images like !"alt text":http://example.com OR !image_url!
#     /^\s*\|.*?\|\s*$/m, # Tables like |...| (pipes at start and end of line)
#   ]
#
#   # Check for Markdown patterns
#   markdown_detected = markdown_patterns.any? { |pattern| m = text.match?(pattern); p pattern.to_s + ' ' + m.to_s; m }
# 
#   # Check for Textile patterns
#   textile_detected = textile_patterns.any? { |pattern| m = text.match?(pattern); p pattern.to_s + ' ' + m.to_s; m }
#   if markdown_detected && !textile_detected
#     'common_mark'
#   elsif textile_detected && !markdown_detected
#     'textile'
#   else
#     'common_mark'
#   end
# end