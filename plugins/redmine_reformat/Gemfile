gem 'net-http-persistent'
gem 'webrick', '~> 1.6'

# commonmarker with patch for fixing sourcepos values
# see https://github.com/commonmark/cmark/pull/298
# strikethrough sourcepos is not adressed though
gem 'commonmarker_fixed_sourcepos',
     git: 'https://github.com/orchitech/commonmarker',
     branch: 'fix-sourcepos'

group :test do
  gem 'webmock'
end
