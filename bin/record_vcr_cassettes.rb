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
    @updated_files = []
    @original_vcr_patterns = {}
  end

  # Find cassette paths and check if they exist before recording
  def find_cassette_paths
    cassette_paths = @cassette_names.map do |name|
      # VCR typically stores cassettes in spec/support/vcr_cassettes/
      path = File.join('spec', 'support', 'vcr_cassettes', "#{name}.yml")
      
      # Also check for module-specific paths
      module_path = nil
      if spec_path.include?('modules/')
        module_name = spec_path.match(/modules\/([^\/]+)/).to_a[1]
        if module_name
          mod_path = File.join('modules', module_name, 'spec', 'support', 'vcr_cassettes', "#{name}.yml")
          module_path = mod_path if File.exist?(mod_path)
        end
      end
      
      [name, { 
        path: path, 
        exists: File.exist?(path), 
        module_path: module_path,
        module_exists: module_path && File.exist?(module_path)
      }]
    end.to_h
    
    # Return a hash of cassette name => info
    cassette_paths
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
        # Find cassettes and check if they exist before running the spec
        cassette_info = find_cassette_paths
        
        # Enable VCR debug logging for this run
        enable_vcr_debug_logging
        
        # Run the spec to record VCR cassettes
        run_spec
        
        # Check which cassettes were updated
        updated_cassettes = []
        cassette_info.each do |name, info|
          path = info[:path]
          module_path = info[:module_path]
          
          if File.exist?(path) && (!info[:exists] || File.mtime(path) > File.mtime(backup_path))
            updated_cassettes << path
            @updated_files << path
          end
          
          if module_path && File.exist?(module_path) && 
             (!info[:module_exists] || File.mtime(module_path) > File.mtime(backup_path))
            updated_cassettes << module_path
            @updated_files << module_path
          end
        end
        
        puts "\nVCR cassettes have been recorded. Check the changes in the cassette files."
        if updated_cassettes.any?
          puts "\nUpdated cassettes:"
          updated_cassettes.each { |path| puts "  - #{path}" }
          
          # Let's provide advice on checking for sensitive data
          puts "\n⚠️  Remember to check the updated cassettes for sensitive data!"
          puts "   Run the following command to inspect each cassette:"
          updated_cassettes.each do |path|
            puts "   grep -i 'http\\|token\\|key\\|secret\\|password\\|auth\\|api_key' #{path}"
          end
        else
          puts "\nNo cassette files were updated. Check your VCR configuration."
        end
        
        # Update run_at timestamps permanently in the spec file
        if @run_at_updated
          update_run_at_timestamps
          @updated_files << spec_path
        end
        
        # Remove :record => :all from spec file
        clean_record_all_from_spec
        
        # Create transfer manifest
        create_transfer_manifest if @updated_files.any?
        
        puts 'Original spec file has been restored from backup with updated run_at timestamps.' if @run_at_updated
        puts 'Removed :record => :all from spec file to prevent accidental re-recording.'
      else
        puts 'No VCR cassettes found in the spec file.'
      end
    rescue => e
      puts "Error: #{e.message}"
      restore_from_backup if File.exist?(backup_path)
      return false
    ensure
      restore_from_backup(keep_run_at: @run_at_updated) if File.exist?(backup_path)
    end

    true
  end

  private

  def create_backup
    FileUtils.cp(spec_path, backup_path)
    puts "Backup created at #{backup_path}"
  end

  def restore_from_backup(keep_run_at: false)
    unless keep_run_at
      FileUtils.cp(backup_path, spec_path)
    end
    FileUtils.rm(backup_path)
  end

  def enable_vcr_debug_logging
    vcr_rb_path = File.join(Dir.pwd, 'spec', 'support', 'vcr.rb')
    
    if File.exist?(vcr_rb_path)
      vcr_content = File.read(vcr_rb_path)
      # If there's a commented out debug logger line, uncomment it temporarily
      if vcr_content.include?('# c.debug_logger')
        puts "Temporarily enabling VCR debug logging..."
        modified_content = vcr_content.gsub('# c.debug_logger', 'c.debug_logger')
        File.write(vcr_rb_path, modified_content)
        @vcr_modified = true
      end
    end
  end

  def update_run_at_timestamps
    content = File.read(spec_path)
    current_time = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
    
    # Update all run_at timestamps in the file
    new_content = content.gsub(/(run_at:\s*['"])([^'"]+)(['"])/) do |_match|
      "#{$1}#{current_time}#{$3}"
    end
    
    if content != new_content
      File.write(spec_path, new_content)
      puts "\nUpdated run_at timestamps to: #{current_time}"
    end
  end
  
  # Clean :record => :all from spec file after recording
  def clean_record_all_from_spec
    content = File.read(spec_path)
    
    # Pattern to match for VCR.use_cassette calls with :record => :all
    pattern = /VCR\.use_cassette\([^)]*:record\s*=>\s*:all[^)]*\)/
    
    # If we have stored original patterns, restore them
    if @original_vcr_patterns.any?
      @original_vcr_patterns.each do |modified_pattern, original_pattern|
        content = content.gsub(modified_pattern, original_pattern)
      end
      File.write(spec_path, content)
      puts "\nRemoved :record => :all from VCR cassette calls"
    else
      # Otherwise just remove any :record => :all
      new_content = content.gsub(/(VCR\.use_cassette\([^,)]*)(,\s*:record\s*=>\s*:all)([^)]*\))/, '\1\3')
      
      if content != new_content
        File.write(spec_path, new_content)
        puts "\nRemoved :record => :all from VCR cassette calls"
      end
    end
  end
  
  # Create a manifest file for transferring updated files
  def create_transfer_manifest
    manifest_path = "#{Dir.pwd}/vcr_transfer_manifest.txt"
    
    File.open(manifest_path, 'w') do |f|
      f.puts "# VCR Transfer Manifest - #{Time.now}"
      f.puts "# The following files were updated and need to be transferred:"
      f.puts "# Use the fetch_vcr_cassettes.sh script to copy these files\n"
      
      @updated_files.each do |file|
        # Store the relative path from the project root
        relative_path = file.sub("#{Dir.pwd}/", '')
        f.puts relative_path
      end
    end
    
    puts "\nCreated transfer manifest at: #{manifest_path}"
    puts "Run the fetch_vcr_cassettes.sh script to copy these files to your local machine."
  end

  def modify_spec_file # rubocop:disable Metrics/MethodLength
    content = File.read(spec_path)
    
    # Find all VCR cassettes used in the spec file
    @cassette_names = []
    pattern = /VCR\.use_cassette\s*\(\s*['"]([^'"]+)['"]/
    content.scan(pattern) do |match|
      @cassette_names << match[0]
    end
    
    # First, update run_at timestamp if present
    current_time = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
    run_at_pattern = /(run_at:\s*['"])([^'"]+)(['"])/
    
    if content.match?(run_at_pattern)
      puts "Found run_at timestamps to update"
      new_content = content.gsub(run_at_pattern) do |_match|
        "#{$1}#{current_time}#{$3}"
      end
      @run_at_updated = (content != new_content)
      content = new_content
    end
    
    # Pattern to match VCR.use_cassette calls
    cassette_pattern = /(VCR\.use_cassette\s*\(\s*['"]([^'"]+)['"]\s*,?\s*([^)]*)\))/
    
    # Store original patterns for later cleanup
    @original_vcr_patterns = {}
    
    new_content = content.gsub(cassette_pattern) do |match|
      cassette_name = ::Regexp.last_match(2)
      options = ::Regexp.last_match(3).strip
      
      # Store the original pattern
      @original_vcr_patterns[match] = match
      
      # Check if :record option is already present
      if options.include?(':record')
        # If it already has :record, replace it with :record => :all
        modified = match.gsub(/(:record\s*=>\s*:[^,)]+)/, ':record => :all')
        @original_vcr_patterns[modified] = match # Store for cleanup
        modified
      elsif options.empty?
        # Add :record => :all option
        modified = "VCR.use_cassette('#{cassette_name}', :record => :all)"
        @original_vcr_patterns[modified] = match # Store for cleanup
        modified
      else
        # Add :record => :all to existing options
        modified = "VCR.use_cassette('#{cassette_name}', #{options}, :record => :all)"
        @original_vcr_patterns[modified] = match # Store for cleanup
        modified
      end
    end
    
    if content != new_content
      @modified = true
      File.write(spec_path, new_content)
      
      puts "Modified #{spec_path} to include :record => :all for VCR cassettes"
      if @run_at_updated
        puts "Updated run_at timestamps to #{current_time}"
      end
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
