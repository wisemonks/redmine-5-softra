require File.expand_path('../../test_helper', __FILE__)

class PlaceholdersTest < ActiveSupport::TestCase
  test "match_context_match should match the longest occurence" do
    text = '- --'.dup
    ph = RedmineReformat::Converters::Placeholders.new(text)
    ph.prepare_text text
    # TODO
  end
end
