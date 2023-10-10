require_relative 'lib/jekyll/new_post/version'

Gem::Specification.new do |spec|
  spec.name = 'jekyll-new_post'
  spec.version = Jekyll::NewPost::VERSION
  spec.authors = ['Mike Slinn']
  spec.email = ['mslinn@mslinn.com']

  spec.summary = 'Makes a new Jekyll post for any collection.'
  spec.homepage = 'https://github.com/mslinn/jekyll-new_post'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/mslinn/jekyll-new_post'
  spec.metadata['changelog_uri'] = 'https://github.com/mslinn/jekyll-new_post/CHANGELOG.md'

  spec.files = Dir['.rubocop.yml', 'LICENSE.*', 'Rakefile', '{lib,spec}/**/*', '*.gemspec', '*.md']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'jekyll'
  spec.add_dependency 'tty-prompt'
end
