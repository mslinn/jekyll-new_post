# `Jekyll::NewPost` [![Gem Version](https://badge.fury.io/rb/jekyll-new_post.svg)](https://badge.fury.io/rb/jekyll-new_post)

This project defines a Jekyll subcommand called `new_post`.
This Jekyll subcommand must be installed into a Jekyll project before it can be used.
The `new_post` subcommand will not be available outside that project.


## Installation

Edit the `Gemfile` of your Jekyll site.
Specify `jekyll-new_post` in the `jekyll_plugins` group, like this:

```ruby
group :jekyll_plugins do
  gem 'jekyll-new_post'
end
```

And then execute:

```shell
$ bundle
```


## Usage

The `demo` subdirectory is a small Jekyll site,
pre-configured with the `new_post` Jekyll subcommand.

```shell
$ cd demo

$ jekyll new_post
```


## Development

After checking out the repo, run `bin/setup` to install dependencies.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run:

```shell
$ bundle exec rake install
```

To release a new version, update the version number in `version.rb`, and then run:

```shell
$ bundle exec rake release
```

The above does the following:

- Creates a git tag for the version
- Pushes git commits and the created tag
- Pushes the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mslinn/jekyll-new_post.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
