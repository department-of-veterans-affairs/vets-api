#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to re-record VCR cassettes for specs
# Usage: ruby bin/record_vcr_cassettes.rb path/to/spec_file.rb[:line_number] [--docker]

require 'fileutils'
require 'optparse'

class VcrRecorder
  attr_reader :spec_path, :backup_path, :modified, :options

  def initialize(spec_path, options = {})
    @spec_path = spec_path.split(':').first # Extract file path without line number
    @line_number = spec_path.include?(':') ? spec_path.split(':').last : nil
    @backup_path = "#{@spec_path}.bak"
    @modified = false
    @options = options
    @vcr_cassette_dirs = detect_vcr_cassette_dirs
    @docker_container = detect_docker_container
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
        copy_cassettes_from_docker if @options[:docker]
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

  def detect_vcr_cassette_dirs
    # Default VCR cassette directories to check
    dirs = [
      'spec/support/vcr_cassettes',
      'spec/vcr_cassettes',
      'spec/fixtures/vcr_cassettes'
    ]

    # Check for module-specific VCR cassette directories
    if spec_path.include?('modules/')
      module_name = spec_path.split('modules/').last.split('/').first
      dirs.unshift("modules/#{module_name}/spec/support/vcr_cassettes")
      dirs.unshift("modules/#{module_name}/spec/vcr_cassettes")
      dirs.unshift("modules/#{module_name}/spec/fixtures/vcr_cassettes")
    end

    # Add any additional directories based on the spec file path
    spec_dir = File.dirname(spec_path)
    if spec_dir.include?('spec')
      relative_path = spec_dir.split('spec/').last
      dirs.unshift("spec/support/vcr_cassettes/#{relative_path}")
    end

    # Filter to only include directories that exist
    dirs.select { |dir| Dir.exist?(dir) }
  end

  def detect_docker_container
    # Try to find the vets-api container
    containers = `docker ps --format '{{.Names}}' | grep vets-api`.strip.split("\n")
    return 'vetsapi_web_1' if containers.empty? # Default fallback

    # Prefer containers with 'web' in the name
    web_containers = containers.select { |c| c.include?('web') }
    return web_containers.first unless web_containers.empty?

    # Otherwise return the first container
    containers.first
  end

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

  def copy_cassettes_from_docker # rubocop:disable Metrics/MethodLength
    return if @cassette_names.empty?

    puts "\nCopying VCR cassettes from Docker container..."
    puts "Using Docker container: #{@docker_container}"

    @cassette_names.each do |cassette_name|
      # Try to find the cassette in all detected directories
      found = false

      @vcr_cassette_dirs.each do |dir|
        cassette_path = "#{dir}/#{cassette_name}.yml"

        # Execute the Docker copy command
        puts "Trying to copy from #{cassette_path}..."
        cmd = "docker cp #{@docker_container}:/app/#{cassette_path} ."

        if system(cmd)
          puts "Successfully copied #{cassette_path}"
          # Change ownership
          filename = File.basename(cassette_path)
          system("sudo chown $USER #{filename}")
          found = true
          break
        end
      end

      unless found
        # Try to find cassette by searching through the file system in Docker
        puts "Searching for cassette '#{cassette_name}.yml' in Docker container..."
        search_cmd = "docker exec #{@docker_container} find /app -name '#{cassette_name}.yml'"
        search_result = `#{search_cmd}`.strip

        if search_result.empty?
          puts "Could not find cassette '#{cassette_name}.yml' in Docker container"
        else
          puts "Found cassette at #{search_result}"
          cmd = "docker cp #{@docker_container}:#{search_result} ."

          if system(cmd)
            puts "Successfully copied #{search_result}"
            filename = File.basename(search_result)
            system("sudo chown $USER #{filename}")
          else
            puts "Failed to copy #{search_result}"
          end
        end
      end
    end
  end
end

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ruby bin/record_vcr_cassettes.rb path/to/spec_file.rb[:line_number] [options]'

  opts.on('--docker', 'Copy cassettes from Docker container') do
    options[:docker] = true
  end

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
  recorder = VcrRecorder.new(spec_path, options)
  exit(recorder.run ? 0 : 1)
rescue OptionParser::InvalidOption => e
  puts e
  puts option_parser
  exit(1)
end
