#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to re-record VCR cassettes for specs
# Usage: ruby bin/record_vcr_cassettes.rb path/to/spec_file.rb[:line_number]

require 'fileutils'
require 'optparse'

class VcrRecorder
  attr_reader :spec_path, :backup_path, :modified

  def initialize(spec_path)
    @spec_path = spec_path.split(':').first # Extract file path without line number
    @line_number = spec_path.include?(':') ? spec_path.split(':').last : nil
    @backup_path = "#{@spec_path}.bak"
    @modified = false
  end

  def run # rubocop:disable Metrics/MethodLength
    unless File.exist?(spec_path)
      puts "Error: Spec file not found: #{spec_path}"
      return false
    end

    begin
      create_backup
      modify_spec_file
      if @modified
        run_spec
        puts "\nVCR cassettes have been recorded. Check the changes in the cassette files."
        puts 'Original spec file has been restored from backup.'
      else
        puts 'No VCR cassettes found in the spec file.'
      end
    rescue => e
      puts "Error: #{e.message}"
      restore_from_backup if File.exist?(backup_path)
      return false
    ensure
      restore_from_backup if File.exist?(backup_path)
    end

    true
  end

  private

  def create_backup
    FileUtils.cp(spec_path, backup_path)
    puts "Backup created at #{backup_path}"
  end

  def restore_from_backup
    FileUtils.cp(backup_path, spec_path)
    FileUtils.rm(backup_path)
  end

  def modify_spec_file # rubocop:disable Metrics/MethodLength
    content = File.read(spec_path)

    # Find all VCR cassettes used in the spec file
    @cassette_names = []
    pattern = /VCR\.use_cassette\s*\(\s*['"]([^'"]+)['"]/
    content.scan(pattern) do |match|
      @cassette_names << match[0]
    end

    # Pattern to match VCR.use_cassette calls
    pattern = /(VCR\.use_cassette\s*\(\s*['"]([^'"]+)['"]\s*,?\s*([^)]*)\))/

    new_content = content.gsub(pattern) do |match|
      cassette_name = ::Regexp.last_match(2)
      options = ::Regexp.last_match(3).strip

      # Check if :record option is already present
      if options.include?(':record')
        match
      elsif options.empty?
        # Add :record => :all option
        "VCR.use_cassette('#{cassette_name}', :record => :all)"
      else
        "VCR.use_cassette('#{cassette_name}', #{options}, :record => :all)"
      end
    end

    if content != new_content
      @modified = true
      File.write(spec_path, new_content)
      puts "Modified #{spec_path} to include :record => :all for VCR cassettes"
      puts "Found cassettes: #{@cassette_names.join(', ')}" if @cassette_names.any?
    end
  end

  def run_spec
    spec_command = spec_path.to_s
    spec_command = "#{spec_path}:#{@line_number}" if @line_number

    puts "\nRunning spec to record new cassettes..."
    cmd = "RAILS_ENV=test bundle exec rspec #{spec_command}"
    puts "Executing: #{cmd}"
    system(cmd)
  end
end

option_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby bin/record_vcr_cassettes.rb path/to/spec_file.rb[:line_number]'

  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit
  end
end

begin
  option_parser.parse!

  if ARGV.empty?
    puts option_parser
    exit(1)
  end

  spec_path = ARGV[0]
  recorder = VcrRecorder.new(spec_path)
  exit(recorder.run ? 0 : 1)
rescue OptionParser::InvalidOption => e
  puts e
  puts option_parser
  exit(1)
end
