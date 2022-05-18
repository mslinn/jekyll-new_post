#!/usr/bin/env ruby

# frozen_string_literal: true

require 'colorator'
require 'date'
require 'fileutils'
require 'jekyll'
require 'pathname'
require 'ptools' # gem install ptools
require 'tty-prompt'
require 'yaml'

# This Ruby script makes a new HTML Jekyll draft blog post and opens it for editing.
# See https://www.mslinn.com/blog/2022/03/28/jekyll-plugin-template-collection.html#cmds
class NewPost < Jekyll::Command # rubocop:disable Metrics/ClassLength
  def initialize
    super
    @config = YAML.load_file('_config.yml')
    @prompt = TTY::Prompt.new
  end

  class << self
    # @param prog [Mercenary::Program]
    def init_with_program(prog) # rubocop:disable Metrics/MethodLength
      prog.command(:new_post) do |cmd|
        cmd.description 'Make a new post in a collection'
        cmd.syntax 'new_post [options]'
        cmd.alias :new_post
        cmd.alias :n

        add_build_options(cmd)
        cmd.action do |_, opts| # Never gets called
          puts "cmd.action: opts = #{opts}"
          # Set the reactor to nil so any old reactor will be GCed.
          # We can't unregister a hook so while running tests we don't want to
          # inadvertently keep using a reactor created by a previous test.
          @reload_reactor = nil

          config = configuration_from_options(opts)
          process_with_graceful_fail(cmd, config, Jekyll::Commands::Build)
        end
        process(nil)
        puts 'All done'
      rescue SystemExit, Interrupt
        puts "\nTerminated".cyan
      rescue StandardError => e
        puts e.message.red
      end
    end

    def process(_opts) # rubocop:disable Metrics/MethodLength
      Jekyll::Hooks.register(:site, :after_init) do |_site|
        puts 'Hook site after_init triggered'.cyan
      end
      Jekyll::Hooks.register(:site, :after_reset) do |_site|
        puts 'Hook site after_reset triggered'.cyan
      end
      Jekyll::Hooks.register(:site, :post_read) do |site|
        puts 'Hook site post_read triggered'.cyan
        @site = site
        new_post = NewPost.new
        new_post.make_post(site)
      end
      Jekyll::Hooks.register(:site, :pre_render) do |_site|
        puts 'Hook site pre_render triggered'.cyan
      end
    end
  end

  # Make a new post in one of the collections
  def make_post(site)
    prepare_output_file(site)
    make_output_file

    prepare_output_contents
    output_contents

    return unless @prompt.yes?('Use mem to append code examples to this post?')

    run "cmd.exe /c wt new-tab bash -ilc #{msp}/_bin/mem -a #{filename}"
  end

  private

  def choose_order(collection)
    collection.docs.map { |x| x.data['order'] }.max + 100
  end

  def check_length(min, max, string)
    length = string.length
    if length < min
      "#{min - length} characters too short, please edit"
    elsif length > max
      "#{length - max} characters too long, please edit"
    else
      "#{length} characters, excellent!"
    end
  end

  def edit
    if File.which 'code'
      run 'code .'
    elsif File.which 'notepad'
      run "notepad #{filename}"  # Invokes mslinn's notepad++ script
    elsif File.which 'gedit'
      run "gedit #{filename}"
    else
      echo "No editor defined, please edit '#{filename}' somehow"
      exit 1
    end
  end

  def emit_array(name, value)
    "#{name}: [ #{value} ]\n"
  end

  def emit_scalar(name, value)
    "#{name}: #{value}\n"
  end

  def prepare_output_contents
    @desc = reprompt('Description', 60, 150, @title)
    @css = @prompt.ask('Post CSS (comma delimited):') || ''
    @categories = @prompt.ask('Post Categories (comma delimited):') || ''
    @tags = @prompt.ask('Post Tags (comma delimited):') || ''
    # @keyw = @prompt.ask('Post Keywords (comma delimited):') || ''
    @img = @prompt.ask('Banner image (.png & .webp):') || ''
    @clipboard = @prompt.yes?('Enable code example clipboard icon?')
  end

  def prepare_output_file(site) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
    collections_dir = (@config['collections_dir'] || '.').strip
    collections = @config['collections'] || [{ 'label' => 'posts' }]
    if collections.length < 2
      collection_name = 'posts'
    else
      labels = collections.map(&:first)
      collection_name = @prompt.select('Which collection should the new post be part of? ', labels).strip
    end
    if collection_name == 'posts'
      @prefix = "#{collections_dir}/_drafts"
      @highest = @pdate = @prompt.ask('Publication date', default: Date.today.to_s, date: true).strip
    else
      @prefix = "#{collections_dir}/_#{collection_name}"
      @categories = []
      collection = site.collections.find { |x| x.first == collection_name }[1]
      @pdate = @highest = choose_order(collection)
    end
    puts "This new post will be placed in the '#{@prefix}' directory"
    @title = reprompt('Title', 30, 60, '').strip
    @plc = read_title(@title)
  end

  # @param name - name of front matter variable
  # @param min - minimum length of user-provided value
  # @param max - maximum length of user-provided value
  # @param value - (Optional) initial value
  def reprompt(name, min, max, value) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    spaces = ''.rjust(min, '_')
    count = (((max * 10) - (min * 10) + 5) / 100) + 1
    numbers = '0123456789' * count
    chars = max - min
    loop do
      msg = " Post #{name} (30-60 characters):\n #{spaces}#{numbers[1..chars]}\n"
      value = @prompt.ask(msg, default: value.strip).strip
      case value.length
      when proc { |n| n < min }
        puts "Only #{value.length} characters were provided, but at least #{min} are required."
      when proc { |n| n > max }
        puts "#{value.length} characters were provided, but the maximum allowable is #{max}."
      else
        return value
      end
    end
  end

  # See https://github.com/piotrmurach/tty-prompt/issues/184
  # @param name - name of front matter variable
  # @param min - minimum length of user-provided value
  # @param max - maximum length of user-provided value
  # @param value - (Optional) initial value
  def reprompt2(name, min, max, value) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    spaces = ''.rjust(min, '_')
    count = (((max * 10) - (min * 10) + 5) / 100) + 1
    numbers = '0123456789' * count
    chars = max - min
    msg = "Post #{name} (30-60 characters):\n#{spaces}#{numbers[1..chars]}\n"
    error_msg = lambda do |val|
      puts val.red
      case val.length
      when proc { |n| n < min }
        puts "Only #{val.length} characters provided, need at least #{min}"
      when proc { |n| n > max }
        puts "#{val.length} characters provided, maximum allowable is #{max}"
      else
        ''
      end
    end
    value = @prompt.ask(msg, value: value) do |q|
      q.required true
      q.validate(/\A.{#{min},#{max}}\Z/, error_msg.call('%{value}'))
      # q.validate(/\A.{#{min},#{max}}\Z/)
    end
    puts "\n#{value}"
    value
  end

  def output_contents # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @javascript_end |= ''
    @javascript_inline |= ''
    if @clipboard
      @javascript_end = '/assets/js/clipboard.min.js'
      @javascript_inline = "new ClipboardJS('.copyBtn');"
    end

    today = Date.today
    contents = <<~END_CONTENTS
      ---
      #{emit_array('css',               @css)}
      #{emit_array('categories',        @categories)}
      #{emit_scalar('date',             today)}
      #{emit_scalar('description',      @desc)}
      #{emit_scalar('image',            @img)}
      #{emit_scalar('javascript',       @javascript)}
      #{emit_scalar('javascriptEnd',    @javascript_end)}
      #{emit_scalar('javascriptInline', @javascript_inline)}
      #{emit_scalar('last_modified_at', today)}
      #{emit_scalar('layout',           @blog)}
    END_CONTENTS

    # TODO: handle all collections like this
    if @django
      contents +=
        emit_scalar(order,     HIGHEST) +
        emit_scalar(published, false)
    end

    contents += <<~END_CONTENTS
      #{emit_array('#selectable', false)}
      #{emit_array('tags',        @tags)}
      #{emit_scalar('title',      @title)}
      ---
    END_CONTENTS

    File.write(@filename, contents)
    puts "Created '#{@filename}'"
  end

  # Convert title to lowercase, remove slashes and colons, convert spaces to hyphens
  # @return filename slug [String]
  def read_title(title)
    ptitle = title.strip.gsub(' ', '-')
    @plc = ptitle.downcase.gsub(/[^0-9a-z_-]/i, '')
    @prompt.ask('Filename slug (without date/seq# or filetype): ', value: @plc)
           .gsub(/[^0-9A-Za-z_-]/i, '')
  end

  def make_output_file
    # Location to create the new file as year-month-day-title.md
    filename = "#{@prefix}/#{@pdate}-#{@plc}.html"
    FileUtils.mkdir_p @prefix
    FileUtils.touch filename # Create the new empty post
    puts filename
  end
end
