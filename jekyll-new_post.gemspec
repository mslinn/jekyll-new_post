require_relative 'lib/jekyll/new_post/version'

Gem::Specification.new do |spec|
  spec.authors     = ['Mike Slinn']
  spec.bindir      = 'exe'
  spec.email       = ['mslinn@mslinn.com']
  spec.executables = spec.files.grep(%r{\Abinstub/}) { |f| File.basename(f) }
  spec.files       = Dir['.rubocop.yml', 'LICENSE.*', 'Rakefile', '{lib,spec}/**/*', '*.gemspec', '*.md']
  spec.homepage    = 'https://github.com/mslinn/jekyll-new_post'
  spec.license     = 'MIT'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['changelog_uri']     = 'https://github.com/mslinn/jekyll-new_post/CHANGELOG.md'
  spec.metadata['homepage_uri']      = spec.homepage
  spec.metadata['source_code_uri']   = 'https://github.com/mslinn/jekyll-new_post'

  spec.name                  = 'jekyll-new_post'
  spec.platform              = Gem::Platform::RUBY
  spec.require_paths         = ['lib']
  spec.required_ruby_version = '>= 2.6.0'
  spec.summary               = 'Makes a new Jekyll post for any collection.'
  spec.version               = Jekyll::NewPost::VERSION

  spec.add_dependency 'jekyll'
  spec.add_dependency 'jekyll_plugin_logger'
  spec.add_dependency 'tty-prompt'
end
