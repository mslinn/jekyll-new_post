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
    def init_with_program(prog)
      prog.command(:new_post) do |_c|
        project_root = Pathname.new(__dir__).parent.to_s
        puts "Executing from #{project_root}".cyan
        new_post = NewPost.new
        new_post.make_post
      rescue SystemExit, Interrupt
        puts "\nTerminated".cyan
      rescue StandardError => e
        puts e.message.red
      end
    end
  end

  # Make a new post in one of the collections
  def make_post # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
    collections_dir = @config['collections_dir'] || '.'
    collections = @config['collections'] || [{ 'label' => 'posts' }]
    if collections.length < 2
      collection_name = 'posts'
    else
      labels = collections.map { |c| c['label'] }
      collection_name = @prompt.multi_select('Which collection should the new post be part of? ', labels)
    end
    if collection_name == 'posts'
      @prefix = "#{collections_dir}/_drafts"
      @highest = @prompt.ask('Publication date', default: Date.today.to_s, date: true)
    else
      @prefix = "#{collections_dir}/#{collection_name}"
      @categories = []
      collection = collections.find { |x| x['label'] == collection_name }
      @highest = choose_order(collection)
    end
    puts "This new post will be placed in the '#{@prefix}' directory"
    @title = reprompt('Title', 30, 60, '')
    @plc = read_title
    make_output_file

    @desc = reprompt('Description', 60, 150, title)
    @css = @prompt.ask('Post CSS (comma delimited): ')
    @categories = @prompt.ask('Post Categories (comma delimited): ')
    @tags = @prompt.ask('Post Tags (comma delimited): ')
    # @keyw = @prompt.ask('Post Keywords (comma delimited): ')
    @img = @prompt.ask('Banner image (.png & .webp): ')
    @clipboard = @prompt.yes?('Enable code example clipboard icon?')
    output_contents

    # edit

    return unless @prompt.yes?('Use mem to append code examples to this post?')

    run "cmd.exe /c wt new-tab bash -ilc #{msp}/_bin/mem -a #{filename}"
  end

  private

  def choose_order(collection)

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
      value = @prompt.ask("Post #{name} (30-60 characters):\n#{spaces}#{numbers[1..chars]}\n", default: value)
      case value.length
      when proc { |n| n < min }
        "Only #{value.length} characters were provided, but at least #{min} are required."
      when proc { |n| n > max }
        "#{value.length} characters were provided, maximum allowable is #{max}."
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
        "Only #{val.length} characters provided, need at least #{min}"
      when proc { |n| n > max }
        "#{val.length} characters provided, maximum allowable is #{max}"
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
    if @clipboard
      javascript_end = '/assets/js/clipboard.min.js'
      javascript_inline = 'new ClipboardJS('.copyBtn');'
    end

    contents <<~END_CONTENTS
      ---
      #{emit_array('css',               css)}
      #{emit_array('categories',        categories)}
      #{emit_scalar('date',             Date.today)}
      #{emit_scalar('description',      desc)}
      #{emit_scalar('image',            img)}
      #{emit_scalar('javascript',       javascript)}
      #{emit_scalar('javascriptEnd',    javascript_end)}
      #{emit_scalar('javascriptInline', javascript_inline)}
      #{emit_scalar('last_modified_at', Date.today)}
      #{emit_scalar('layout',           blog)}
    END_CONTENTS

    # TODO: handle all collections like this
    if @django
      contents +=
        emit_scalar(order,     HIGHEST) +
        emit_scalar(published, false)
    end

    contents += <<~END_CONTENTS
      #{emit_array('#selectable', false)}
      #{emit_array('tags',        tags)}
      #{emit_scalar('title',      title)}
      ---
    END_CONTENTS

    File.write(filename, contents)
    puts "Created '#{filename}'"
  end

  # Convert title to lowercase, remove slashes and colons, convert spaces to hyphens
  def read_title
    ptitle = @title.strip.gsub(' ', '-')
    plc = ptitle.downcase.gsub('[/:]', '')
    @prompt.ask('Filename slug (without date/seq# or filetype): ', default: plc)
  end

  def make_output_file
    # Location to create the new file as year-month-day-title.md
    filename = "#{@prefix}/#{pdate}-#{plc}.html"
    File.mkdirs @prefix
    FileUtils.touch filename # Create the new empty post
    puts filename
  end
end

# Invoke this code this way:
# $ cd demo
# $ ruby ../lib/jekyll/new_post.rb
if __FILE__ == $PROGRAM_NAME
  begin
    project_root = Pathname.new(__dir__).parent.to_s
    puts "Executing from #{project_root}".cyan
    new_post = NewPost.new

    site_root = Pathname.new "#{project_root}/_site"
    abort 'Error: The _site/ directory does not exist.' unless site_root.exist?
    Dir.chdir site_root

    new_post.reprompt('Test', 10, 20, 'Blah')
  rescue SystemExit, Interrupt
    puts "\nTerminated".cyan
  rescue StandardError => e
    puts e.message.red
  end
end
