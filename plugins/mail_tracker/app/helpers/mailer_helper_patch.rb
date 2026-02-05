module MailerHelperPatch
  def self.included(base)
    base.class_eval do

      def detect_format(text)
        markdown_patterns = [
          /\[.*?\]\(.*?\)/,
          /\!\[.*?\]\(.*?\)/,
          /<h\d>/,
          /<strong>.*?<\/strong>/,
          /<em>.*?<\/em>/,
          /<a.*?>.*?<\/a>/,
          /<img.*?>/,
          /<table.*?>.*?<\/table>/,
          /<ul>.*?<\/ul>/,
          /<ol>.*?<\/ol>/,
          /<li>.*?<\/li>/,
          /<code>.*?<\/code>/,
          /<pre>.*?<\/pre>/,
          /<blockquote>.*?<\/blockquote>/,
          /<hr>/,
          /<br>/,
          /<p>.*?<\/p>/,
          /<span.*?>.*?<\/span>/,
          /<div.*?>.*?<\/div>/
        ]
      
        textile_patterns = [
          /^\s*h\d\.\s/,
          /".*?":http.*?/,
          /!\[.*?\]:.*?|!\[.*?\]:.*?|!\[.*?\]!/,
          /\|.*?\|/,
        ]

        markdown_detected = markdown_patterns.any? { |pattern| m = text.match?(pattern); p pattern.to_s + ' ' + m.to_s; m }
      
        textile_detected = textile_patterns.any? { |pattern| m = text.match?(pattern); p pattern.to_s + ' ' + m.to_s; m }
        if markdown_detected && !textile_detected
          'common_mark'
        elsif textile_detected && !markdown_detected
          'textile'
        else
          'common_mark'
        end
      end

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
          formatting = detect_format(text)
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
