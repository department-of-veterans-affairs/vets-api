#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to automatically fix common logging anti-patterns in vets-api
# Usage: ruby fix_logging_patterns.rb /path/to/vets-api [--dry-run]

require 'find'
require 'fileutils'

class LoggingPatternFixer
  def initialize(root_path, dry_run: false)
    @root_path = root_path
    @dry_run = dry_run
    @changes = []
    @files_modified = 0
  end

  def fix_all
    puts "🔧 #{@dry_run ? 'DRY RUN: ' : ''}Fixing logging patterns in: #{@root_path}"
    puts "=" * 80

    scan_and_fix
    generate_summary
  end

  private

  def scan_and_fix
    ruby_files = []

    Find.find(@root_path) do |path|
      # Skip certain directories
      if FileTest.directory?(path)
        # Only skip build artifacts and vendor code
        if path.match?(%r{/(node_modules|tmp|log|coverage|\.git|vendor|public/packs)/})
          Find.prune
        else
          next
        end
      end

      # Only process Ruby files
      next unless path.end_with?('.rb')
      next if path.include?('/db/migrate/') # Skip migrations

      ruby_files << path
    end

    puts "📁 Found #{ruby_files.length} Ruby files to process\n\n"

    ruby_files.each { |file| process_file(file) }
  end

  def process_file(file_path)
    original_content = File.read(file_path)
    content = original_content.dup
    relative_path = file_path.sub(@root_path, '').sub(%r{^/}, '')
    file_changed = false

    # Fix 1: Remove duplicate log_exception_to_rails when log_exception_to_sentry is present
    content.gsub!(/(\s*)log_exception_to_sentry\((.*?)\)\n(\s*)log_exception_to_rails\((.*?)\)/m) do |match|
      indent = Regexp.last_match(1)
      sentry_args = Regexp.last_match(2)
      rails_indent = Regexp.last_match(3)
      rails_args = Regexp.last_match(4)

      @changes << {
        file: relative_path,
        type: :remove_duplicate_rails_logging,
        details: "Removed log_exception_to_rails after log_exception_to_sentry"
      }
      file_changed = true

      "#{indent}log_exception_to_sentry(#{sentry_args})"
    end

    # Fix 2: Remove duplicate log_message_to_rails when log_message_to_sentry is present
    content.gsub!(/(\s*)log_message_to_sentry\((.*?)\)\n(\s*)log_message_to_rails\((.*?)\)/m) do |match|
      indent = Regexp.last_match(1)
      sentry_args = Regexp.last_match(2)

      @changes << {
        file: relative_path,
        type: :remove_duplicate_rails_message_logging,
        details: "Removed log_message_to_rails after log_message_to_sentry"
      }
      file_changed = true

      "#{indent}log_message_to_sentry(#{sentry_args})"
    end

    # Fix 3: Replace puts/print with Rails.logger in non-spec files
    unless file_path.include?('/spec/')
      # Match puts with string argument
      content.gsub!(/^(\s+)puts\s+['"](.+?)['"](\s*)$/m) do |match|
        indent = Regexp.last_match(1)
        message = Regexp.last_match(2)

        @changes << {
          file: relative_path,
          type: :replace_puts_with_logger,
          details: "Replaced puts with Rails.logger.info"
        }
        file_changed = true

        "#{indent}Rails.logger.info('#{message}')"
      end

      # Match puts with variable
      content.gsub!(/^(\s+)puts\s+([a-z_][a-z0-9_.]*)(\s*)$/i) do |match|
        indent = Regexp.last_match(1)
        var = Regexp.last_match(2)

        @changes << {
          file: relative_path,
          type: :replace_puts_with_logger,
          details: "Replaced puts with Rails.logger.info"
        }
        file_changed = true

        "#{indent}Rails.logger.info(#{var})"
      end
    end

    # Fix 4: Standardize ::Rails.logger to Rails.logger
    if content.gsub!(/::Rails\.logger/, 'Rails.logger')
      @changes << {
        file: relative_path,
        type: :standardize_rails_logger,
        details: "Removed :: prefix from Rails.logger calls"
      }
      file_changed = true
    end

    # Fix 5: Convert direct Sentry.capture_exception to log_exception_to_sentry (when not in a rescue block)
    # This is more conservative - only suggest, don't auto-fix
    if content.match?(/Sentry\.capture_exception/)
      @changes << {
        file: relative_path,
        type: :manual_review_needed,
        details: "Contains Sentry.capture_exception - consider using log_exception_to_sentry for consistency"
      }
    end

    # Write changes if not dry run and file was modified
    if file_changed
      if @dry_run
        puts "  [DRY RUN] Would modify: #{relative_path}"
      else
        File.write(file_path, content)
        puts "  ✅ Modified: #{relative_path}"
        @files_modified += 1
      end
    end
  end

  def generate_summary
    puts "\n" + "=" * 80
    puts "📊 #{@dry_run ? 'DRY RUN ' : ''}SUMMARY"
    puts "=" * 80 + "\n\n"

    if @dry_run
      puts "🔍 Changes that would be made:\n\n"
    else
      puts "✅ Changes made:\n\n"
    end

    grouped_changes = @changes.group_by { |c| c[:type] }

    grouped_changes.each do |type, changes|
      puts "#{type.to_s.gsub('_', ' ').upcase}:"
      puts "  Total instances: #{changes.length}"

      files = changes.map { |c| c[:file] }.uniq
      puts "  Files affected: #{files.length}"

      if files.length <= 10
        files.each { |f| puts "    • #{f}" }
      else
        files.first(10).each { |f| puts "    • #{f}" }
        puts "    ... and #{files.length - 10} more"
      end
      puts "\n"
    end

    if @dry_run
      puts "\n💡 To apply these changes, run without --dry-run flag"
    else
      puts "\n✅ Modified #{@files_modified} files with #{@changes.length} total changes"
      puts "\n⚠️  Remember to:"
      puts "  1. Run your test suite"
      puts "  2. Review the changes with git diff"
      puts "  3. Commit changes in logical groups"
    end

    # Export change log
    export_change_log
  end

  def export_change_log
    output_file = "logging_fixes_#{@dry_run ? 'plan' : 'applied'}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"

    File.open(output_file, 'w') do |f|
      f.puts "Logging Pattern #{@dry_run ? 'Fix Plan' : 'Changes Applied'}"
      f.puts "Generated: #{Time.now}"
      f.puts "=" * 80
      f.puts

      @changes.group_by { |c| c[:file] }.each do |file, file_changes|
        f.puts "#{file}:"
        file_changes.each do |change|
          f.puts "  - [#{change[:type]}] #{change[:details]}"
        end
        f.puts
      end
    end

    puts "\n📝 Change log exported to: #{output_file}"
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby fix_logging_patterns.rb /path/to/vets-api [--dry-run]"
  puts "\nOptions:"
  puts "  --dry-run    Show what would be changed without making changes"
  exit 1
end

root_path = ARGV[0]
dry_run = ARGV.include?('--dry-run')

fixer = LoggingPatternFixer.new(root_path, dry_run: dry_run)
fixer.fix_all
