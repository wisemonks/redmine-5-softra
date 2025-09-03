# frozen_string_literal: true

module RedmineReformat
  module Converters
    module MarkdownToCommonmark

      class Converter
        GfmEditor = RedmineReformat::Converters::GfmEditor

        def initialize(opts = {})
          @replaces = {
            hard_wrap: opts.fetch(:hard_wrap, true),
            underline: opts.fetch(:underline, true),
          }
          @superscript = opts.fetch(:superscript, true)
          @silent = opts.fetch(:silent, false)

          # developer use
          nodelog_fname = opts.fetch(:debug_nodelog, nil)
          @nodelog_f = File.open(nodelog_fname, "w") if nodelog_fname
          @nodelog_f.sync = true if @nodelog_f
        end

        # libcmark / cmark-gfm debugging / integration testing
        def nodelog(text)
          e = GfmEditor.new(text)
          e.document.walk do |node|
            e.source(node, /\A(.).*?(.)?\z/m) do |source, range, m|
              d1, d2 = m[1], m[2]
              case node.type
              when :paragraph, :text, :document, :table_cell
                d1 = d2 = nil
              when :list_item, :list, :header, :blockquote
                d2 = nil
              end
              entry = "#{node.type},#{d1},#{d2}".gsub("\r", "CR").gsub("\n", "LF")
              nodelog_f.syswrite "#{entry}\n"
            end
          end
        end

        def convert(text, ctx = nil)
          return text if text.empty?
          reference = ctx && ctx.ref
          converted = text.dup
          macros = extract_macros(converted)
          begin
            nodelog(text) if @nodelog_f
            # structural changes first
            converted = outplace_superscript(converted) if @superscript
            converted = replace(converted, @replaces) if @replaces.values.any?
          rescue Exception => e
            unless @silent
              msg = String.new
              msg << "Failed MarkdownToCommonmark '#{reference}' due to #{e.message} - #{e.class}\n"
              msg << "The text was:\n"
              msg << "#{'-' * 80}\n"
              msg << "#{text}\n"
              msg << "#{'-' * 80}\n"
              STDERR.print msg
            end
            raise
          end
          restore_macros(converted, macros)
          converted
        end

        private
        include RedmineReformat::Converters::Macros

        SUPERSCRIPT_RE = /
            \^
            (?:
              ([^\s(]\S*)          # plain content
            |
              \((.*?)(?:\)|\\(.?)) # parenthesized content, esctrailer
            )
          /xm

        # Nonstructural replaces not affecting the document structure
        # Recognized opts: :hard_wrap and :underline
        def replace(text, opts)
          e = GfmEditor.new(text)
          macrotext = false
          e.document.walk do |node|
            if opts[:hard_wrap] && node.type == :softbreak
              spos = e.sourcepos(node)
              lineno = spos && spos.start_line
              lineno and e.line(lineno, NL_MACRO_RE) do |line, range, m|
                if macrotext && e.line?(lineno + 1) && /^}}/ =~ e.line(lineno + 1)
                  macrotext = false
                elsif m['macro']
                  macrotext = true if m['macro'].include?('macrotext')
                else
                  e.insert(m.begin('nl'), '  ', range)
                end
              end
            end
            if opts[:underline] && node.type == :emph
              e.source(node, /\A([_*]).*(\1)\z/m) do |source, range, m|
                if m[1] == '_'
                  e.replace(m.begin(1)...m.end(1), '<ins>', range)
                  e.replace(m.begin(2)...m.end(2), '</ins>', range)
                end
              end
            end
          end
          e.apply
        end

        def outplace_superscript(text)
          e = GfmEditor.new(text)
          protect_until_idx = 0
          e.document.walk do |node|
            if node.type == :text
              spos = e.inner_sourcepos(node.parent)
              next unless spos
              parentctx = e.source_range(spos)
              e.source(node) do |textsrc, textctx|
                textsrc.scan(/(?<!\\)(?:\\\\)*(\^)/m) do
                  m = Regexp.last_match
                  sup_evalctx = (textctx.min + m.begin(1))..parentctx.max
                  next if sup_evalctx.min < protect_until_idx
                  text[sup_evalctx].match(SUPERSCRIPT_RE) do |bm|
                    protect_until_idx = sup_evalctx.min + bm.end(0)
                    body = bm[1] || bm[2]
                    trailer = superscript_esc_trailer(bm[3])
                    suprng = bm.begin(0)...bm.end(0)
                    newbody, restart = superscript_process_body(body)
                    replacement = "<sup>#{newbody}#{trailer}</sup>"
                    e.replace(suprng, replacement, sup_evalctx)
                    return outplace_superscript(e.apply) if restart
                  end
                end
              end
            end
          end
          e.apply
        end

        # Process eventual nested superscripts and ensure non-delimiting delimiter chars are
        # escaped to prevent them to bind to the subsequent text.
        # Returns processed superscript body and a flag indicating whether the subsequent
        # text might have changed interpretation.
        def superscript_process_body(text)
          # nested superscripts are rare, save CPU...
          text = outplace_superscript(text) if text.include? '^'
          # escape delimiter characters in text nodes, as they are bound to this superscript
          e = GfmEditor.new(text)
          e.document.walk do |node|
            if node.type == :text
              e.source(node) do |textsrc, textctx|
                textsrc.scan(/(?<!\\)(?:\\\\)*([*~`]|(?<!\w)_|_(?!\w))/m) do
                  m = Regexp.last_match
                  e.insert(m.begin(1), '\\', textctx)
                end
              end
            end
          end
          [e.apply, e.editcount.positive?]
        end

        # ^`(sup\x` renders as `<sup>sup\</sup>`, the x is always dropped.
        # weird, but we should not drop any user content
        def superscript_esc_trailer(x)
          return '' unless x
          case x
          when '', '\\', /\s/
            '\\\\'
          else
            "\\\\<!-- #{x} -->"
          end
        end
      end
    end
  end
end
