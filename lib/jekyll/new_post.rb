#!/usr/bin/env ruby

# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'pathname'
require "ptools" # gem install ptools
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
    def init_with_program(prog) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      prog.command(:new_post) do |_c|
        project_root = Pathname.new(__dir__).parent.to_s
        puts "Executing from #{project_root}".cyan
        new_post = NewPost.new

        site_root = Pathname.new "#{project_root}/_site"
        abort "Error: The _site/ directory does not exist." unless site_root.exist?
        Dir.chdir site_root

        check_config_env_vars
        new_post.make_post
      rescue SystemExit, Interrupt
        puts "\nTerminated".cyan
      rescue StandardError => e
        puts e.message.red
      end
    end
  end

  private

  def choose_order(collection)

  end

  # Make a new post in one of the collections
  def make_post # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    collections_dir = @config.collections_dir || '.'
    collections = @config.collections
    labels = collections.map(&:label)
    collection_name = @prompt.multi_select("Which collection should the new post be part of? ", labels)
    if collection_name == 'posts'
      prefix = "#{collections_dir}/_drafts"
      @highest = @prompt.ask? "Publication date: ", Date.today.to_s
    else
      prefix = "#{collections_dir}/#{collection_name}"
      @categories = []
      collection = collections.find { |x| x.label == collection_name }
      @highest = choose_order(collection)
    end
    puts "This new post will be placed in the '#{prefix}' directory"
    @title = reprompt("Title", 30, 60)
    @plc = read_title
    make_output_file

    @desc = reprompt("Description", 60, 150, title)
    @css = @prompt.ask?("Post CSS (comma delimited): ")
    @categories = @prompt.ask?("Post Categories (comma delimited): ")
    @tags = @prompt.ask?("Post Tags (comma delimited): ")
    # @keyw = @prompt.ask?("Post Keywords (comma delimited): ")
    @img = @prompt.ask?("Banner image (.png & .webp): ")
    @clipboard = @prompt.yes?("Enable code example clipboard icon?")
    output_contents

    # edit

    return unless @prompt.yes?("Use mem to append code examples to this post?")

    run "cmd.exe /c wt new-tab bash -ilc #{msp}/_bin/mem -a #{filename}"
  end

  def check_length(min, max, string) # rubocop:disable Metrics/MethodLength
    # $1 - minimum length
    # $2 - maximum length
    # $3 - string to test
    length = string.length
    if length < min
      puts "#{min - length} characters too short, please edit"
      1
    elsif length > max
      puts "#{length - max} characters too long, please edit"
      2
    else
      puts "#{length} characters, excellent!"
      0
    end
  end

  def edit
    if File.which 'code'
      run "code ."
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
  def reprompt(name, min, max, value) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    unless name
      puts "Error: no front matter variable provided"
      exit 1
    end
    unless min
      puts "Error: no minimum length provided"
      exit 1
    end
    unless max
      puts "Error: no maximum length provided"
      exit 1
    end

    spaces = "".rjust(min, " ")
    count = ((max * 10) - (min * 10) + 5) / 10
    numbers = "0123456789" * count
    chars = max - min
    loop do
      puts "Post #{name} (30-60 characters):\n#{spaces}#{numbers[1..chars]}\n"
      value = gets.chomp
      break if checkLength(min, max, value)
    end
    puts "\n#{value}"
  end

  # Set cwd to project root
  def check_config_env_vars
    return if File.exist? "_bin/loadConfigEnvVars"

    puts "Error: _bin/loadConfigEnvVars was not found."
    exit 1
  end

  def output_contents # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    if @clipboard
      javascript_end = "/assets/js/clipboard.min.js"
      javascript_inline = "new ClipboardJS('.copyBtn');"
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
      #{emit_array("#selectable", "false")}
      #{emit_array('tags',        tags)}
      #{emit_scalar('title',      title)}
      ---
    END_CONTENTS

    File.write(filename, contents)
    puts "Created '#{filename}'"
  end

  # Convert title to lowercase, remove slashes and colons, convert spaces to hyphens
  def read_title
    ptitle = title.gsub(' ', '=')
    plc = ptitle.downcase.gsub('[/:]', '')
    @prompt.ask("Filename slug (without date/seq# or filetype): ", default: plc)
  end

  def make_output_file
    # Location to create the new file as year-month-day-title.md
    filename = "#{prefix}/#{pdate}-#{plc}.html"
    File.mkdirs prefix
    FileUtils.touch filename # Create the new empty post
    puts filename
  end
end
