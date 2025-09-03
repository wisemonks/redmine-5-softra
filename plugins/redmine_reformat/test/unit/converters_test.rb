require File.expand_path('../../test_helper', __FILE__)

class ConvertersTest < ActiveSupport::TestCase
  Converters = RedmineReformat::Converters
  Context = RedmineReformat::Context
  fixtures :projects,
           :users, :email_addresses, :user_preferences,
           :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_relations,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields, :custom_values, :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals, :journal_details,
           :queries,
           :repositories, :changesets,
           :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions

  test 'should respect project and item' do
    text = 'h1. Example'
    exp_ws = mock_ws_response(2, mock_ws_response(1, text))
    exp_md = '# Example'
    conv = configured_converters
    # projects
    tests = [[1, exp_ws], [2, exp_ws], [3, exp_md], [nil, exp_md]]
    ctx = Context.new(item: 'Issue', from_formatting: 'textile')
    tests.each do |project_id, expected|
      ctx.project_id = project_id
      assert_equal expected, conv.convert(text, ctx)
    end
    # items
    tests = [
      ['Issue', exp_ws],
      ['JournalDetail[Issue.description]', exp_ws],
      ['Journal', exp_ws],
      ['Message', exp_md]
    ]
    ctx = Context.new(project_id: 1, from_formatting: 'textile')
    tests.each do |item, expected|
      ctx.item = item
      assert_equal expected, conv.convert(text, ctx)
    end
  end

  test 'should return as is' do
    ctx = Context.new(item: 'EmptyConversionItem')
    text = 'test'
    assert_equal text, configured_converters.convert(text, ctx)
  end

  test 'should convert to CRLF' do
    ctx = Context.new(item: 'EmptyConversionItem')
    text = "l1\nl2\n\n"
    expected = "l1\r\nl2\r\n\r\n"
    assert_equal expected, configured_converters.convert(text, ctx)
  end

  test 'should suggest to skip' do
    ctx = Context.new(item: 'SkippedItem')
    assert_nil configured_converters.convert('test', ctx)
  end

  test 'should fail on undefined converter' do
    ctx = Context.new(from_formatting: 'weird')
    assert_raises RuntimeError do
      configured_converters.convert('test', ctx)
    end
  end

  test 'should restore stripped [CR]LF' do
    conv = configured_converters
    ctx = Context.new(item: 'StripItem')
    assert_equal "test\r\n", conv.convert("test\r\n", ctx)
    assert_equal "test\r\n", conv.convert("test\n", ctx)
  end

  test 'should strip added [CR]LF' do
    conv = configured_converters
    text = 'test'
    ctx = Context.new
    ['AddCrlfItem', 'AddLfItem'].each do |item|
      ctx.item = item
      assert_equal text, conv.convert(text, ctx)
    end
  end

  private
  def mock_ws_uri(id)
    uri = "http://ws#{id}.reformat.example.net"
    @webmocks ||= {}
    @webmocks[id] ||= stub_request(:any, uri)
      .to_return {|req| {body: mock_ws_response(id, req.body)}}
    uri
  end

  def mock_ws_response(id, request_body)
    case id
    when :strip
      request_body.strip
    when :add_lf
      "#{request_body}\r\n"
    when :add_crlf
      "#{request_body}\r\n"
    else
      "WS#{id}: #{request_body}"
    end
  end

  def configured_converters
    json = <<-JSON.strip_heredoc
    [
      {
        "projects": [
          "onlinestore",
          1
        ],
        "items": [
          "Issue",
          "JournalDetail[Issue.description]",
          "Journal"
        ],
        "converters": [
          ["Ws", "#{mock_ws_uri(1)}"],
          ["Ws", "#{mock_ws_uri(2)}"]
        ]
      },
      {
        "items": "EmptyConversionItem",
        "converters": []
      },
      {
        "items": "SkippedItem",
        "converters": null
      },
      {
        "items": "StripItem",
        "converters": ["Ws", "#{mock_ws_uri(:strip)}"]
      },
      {
        "items": "AddLfItem",
        "converters": ["Ws", "#{mock_ws_uri(:add_lf)}"]
      },
      {
        "items": "AddCrlfItem",
        "converters": ["Ws", "#{mock_ws_uri(:add_crlf)}"]
      },
      {
        "from_formatting": "textile",
        "converters": [
          ["TextileToMarkdown"]
        ]
      }
    ]
    JSON
    Converters::from_json(json)
  end
end
