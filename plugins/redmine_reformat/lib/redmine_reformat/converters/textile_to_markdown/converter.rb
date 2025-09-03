# frozen_string_literal: true

require 'set'
require 'open3'
require 'tempfile'
require 'timeout'

module RedmineReformat
  module Converters
    module TextileToMarkdown

      class Converter
        def convert(text, ctx = nil)
          Conversion.new(text, ctx).call
        end
      end

      private
      class Conversion
        PANDOC_COMMAND = [
          'pandoc',
          '--wrap=preserve',
          '-f',
          'textile-smart',
          '-t',
          'gfm'
        ]
        PANDOC_RECOVERABLE_EXIT_CODES = []

        # receives textile, returns markdown
        def initialize(textile, ctx)
          @textile = textile.dup
          @ctx = ctx
          @reference = ctx.ref
          @placeholders = []
        end

        def call
          return String.new if @textile.empty?
          pre_process_textile @textile

          output = exec_pandoc_with_timeout(stdin: @textile)
          post_process_markdown output if output
        end

        private
        include RedmineReformat::Converters::TextileToMarkdown::PandocPreprocessing

        def pre_process_textile(textile)
          is_redcarpet = @ctx.to_formatting == 'markdown'
          format_opts = {
            # http://www.redmine.org/issues/20497
            list_separator_html_comment: !is_redcarpet,
            # https://www.redmine.org/issues/28169
            underline_underscore: is_redcarpet,
            # https://www.redmine.org/issues/23341
            wiki_links_atomic: false,
            table_pipe_escaping: !is_redcarpet,
          }

          clean_white_space textile
          initialize_reformatter textile, format_opts, @reference

          # Do not interfere with protected blocks
          rip_offtags textile, false, false
          rip_macros textile
          unindent_pre_offtag textile
          # Move the class from <code> to <pre> and remove <code>, so pandoc can generate a code block with correct language
          merge_pre_code_offtags textile

          no_textile textile
          escape_html_tags textile
          block_textile_quotes textile

          # strip surrounding whitespace, which is allowed by Redmine, but would break further processing
          # temprarily placeholderize at the same time to avoid confusion with 'free qtags'
          normalize_hr_to_phs textile

          # make sure that empty lines mean new block
          glue_indented_continuations textile

          # extrect indented code and unindent lists
          process_indented_blocks textile

          # block should be processed here before inlines, but delaying some of them,
          # as their syntax collides with some tricky inline sequences
          hard_break textile
          # TODO: We should eat image attributes here, as image attributes are now causing warnings about
          # unreplaced placeholders when attributes are used.
          inline_textile_link textile # avoid misinterpeation of invalid link-like sequences
          inline_textile_code textile # offtagize inline code
          block_textile_table textile
          revert_hard_break textile

          # all non-interpreted sections are offtagized now
          protect_offtag_contents

          ## make inline vs. block sequence normalizing easier
          protect_wiki_links textile
          normalize_lists_to_phs textile

          # tables vs. inline sequences in them
          protect_pipes_in_tables textile
          guess_table_headers textile

          process_textile_prefix_blocks textile

          # make placeholderes from real qtags
          hard_break textile
          inline_textile_span_to_phs textile
          revert_hard_break textile

          # protect qtag characters that pandoc tend to misinterpret
          # has to be done after unindenting and protecting qtag chars in all semantic contexts
          protect_autolinks textile
          protect_qtag_chars textile

          # finished with qtag characters
          restore_real_qtags textile

          ## restore constructs that use qtag characters
          restore_textile_lists textile
          restore_textile_hrs textile

          # pandoc does not interpret html entities directly following a word
          put_breaks_before_html_entities textile

          # backslash-escaped issue links are ugly and escaped hash can break links
          protect_hashes textile

          # Force <pre> to have a blank line before them in lists
          # Without this fix, a list of items containing <pre> would not be interpreted as a list at all.
          put_blank_line_before_pre_in_list textile

          textile_footnote_refs textile

          # Avoid converting some symbols into special characters
          protect_symbols textile

          # Prefer inline code using backtics over code html tag (code is already protected as an offtag)
          prefer_inline_code_over_html textile

          # prevent sequences of = to be interpreted as <notextile>, see RedmineReformat#no_textile
          protect_eq_sequences textile

          smooth_offtags textile
          textile
        end


        def post_process_markdown(markdown)

          restore_protected_line_breaks markdown
          restore_context_free_placeholders markdown
          restore_qtag_chars_to_md markdown
          md_footnotes markdown
          md_remove_auxiliary_code_block_lang markdown
          md_separate_lists markdown
          # Restore/unescaping sequences that are protected differently in code blocks
          md_polish_before_code_restore markdown
          # Replace code and link placeholders *after* playing with the text
          restore_aftercode_placeholders markdown
          smooth_macros markdown
          normalize_and_rip_fenced_code_blocks markdown
          md_replace_underline markdown
          # This should be the very last thing to break text length in table
          remove_init_breakers markdown
          md_reformat_tables markdown
          smooth_fenced_code_blocks markdown
          # restore placeholders preserving text length
          restore_after_table_reformat_placeholders markdown
          expand_blockqutes markdown

          finalize_reformatter markdown
          markdown
        end

        def exec_pandoc_with_timeout(timeout: 30, stdin:)
          pid = nil
          output = nil
          status = nil
          begin
            Timeout.timeout(timeout) do
              Open3.popen2(PANDOC_COMMAND.join(' ')) do |i, o, t|
                pid = t.pid
                (i << stdin).close
                output = o.read
                status = t.value
              end
            end
          rescue Timeout::Error
            begin
              Process.kill(-9, pid)
            rescue Errno::ESRCH
              # already killed - ignoring
            end
            Process.detach(pid)
            STDERR.puts("[ERROR] #{@reference} - pandoc execution timeout")
            return nil # recoverable
          end

          return nil unless status && status.exited?
          if status.success?
            output
          elsif PANDOC_RECOVERABLE_EXIT_CODES.include? status.exitstatus
            STDERR.puts("[ERROR] #{@reference} - pandoc execution failed (#{status}).")
            nil
          else
            raise "Persistent pandoc error occured, check pandoc version. Aborting. (#{status})"
          end
        end
      end
    end
  end
end
