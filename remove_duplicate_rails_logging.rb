#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

# Script to remove duplicate log_exception_to_rails calls when log_exception_to_sentry is present
# This fixes the duplicate logging anti-pattern where both Sentry and Rails logging happen for the same error

class DuplicateLoggingRemover
  BACKUP_DIR = 'backup_before_logging_cleanup'

  # Files with duplicate logging issues (excluding our own scripts)
  TARGET_FILES = [
    'app/controllers/concerns/exception_handling.rb',
    'app/models/evss_claim_document.rb',
    'app/models/form_profile.rb',
    'app/services/evss_claim_service.rb',
    'app/sidekiq/evss/document_upload.rb',
    'app/sidekiq/evss/failure_notification.rb',
    'app/sidekiq/lighthouse/evidence_submissions/failure_notification_email_job.rb',
    'app/sidekiq/lighthouse/failure_notification.rb',
    'lib/debt_management_center/sidekiq/va_notify_email_job.rb',
    'lib/lighthouse/service_exception.rb',
    'lib/va_profile/contact_information/v2/transaction_response.rb',
    'lib/vets/shared_logging.rb',
    'modules/check_in/app/services/travel_claim/client.rb',
    'modules/dhp_connected_devices/app/controllers/dhp_connected_devices/fitbit/fitbit_controller.rb',
    'app/models/form_attachment.rb',
    'app/models/saved_claim/education_career_counseling_claim.rb',
    'app/services/bgs/awards_service.rb',
    'app/services/bgs/people/service.rb',
    'app/services/bgs/uploaded_document_service.rb',
    'app/sidekiq/pager_duty/cache_global_downtime.rb',
    'app/sidekiq/pager_duty/poll_maintenance_windows.rb',
    'app/sidekiq/va_notify_email_job.rb',
    'lib/bb/client.rb',
    'lib/bb/generate_report_request_form.rb',
    'lib/common/pdf_helpers.rb',
    'lib/preneeds/middleware/response/eoas_xml_errors.rb',
    'modules/test_user_dashboard/app/controllers/test_user_dashboard/application_controller.rb',
    'modules/veteran/app/sidekiq/organizations/update_names.rb',
    'modules/veteran/app/sidekiq/representatives/xlsx_file_fetcher.rb',
    'modules/veteran/app/sidekiq/veteran/vso_reloader.rb',
    'app/sidekiq/education_form/create10203_applicant_decision_letters.rb',
    'app/sidekiq/education_form/create_daily_excel_files.rb',
    'app/sidekiq/education_form/create_daily_spool_files.rb',
    'app/sidekiq/education_form/process10203_submissions.rb'
  ].freeze

  def initialize(root_path, dry_run: false)
    @root_path = root_path
    @dry_run = dry_run
    @changes = []
    @backup_dir = File.join(@root_path, BACKUP_DIR)
  end

  def run
    puts '=' * 80
    puts 'Duplicate Logging Remover'
    puts '=' * 80
    puts "Mode: #{@dry_run ? 'DRY RUN (no changes)' : 'LIVE (making changes)'}"
    puts "Root: #{@root_path}"
    puts '=' * 80
    puts

    create_backup_directory unless @dry_run

    TARGET_FILES.each do |file_path|
      process_file(file_path)
    end

    print_summary
  end

  private

  def create_backup_directory
    FileUtils.mkdir_p(@backup_dir)
    puts "✓ Created backup directory: #{@backup_dir}\n\n"
  end

  def process_file(relative_path) # rubocop:disable Metrics/MethodLength
    full_path = File.join(@root_path, relative_path)

    unless File.exist?(full_path)
      puts "⚠ SKIP: #{relative_path} (file not found)"
      return
    end

    content = File.read(full_path)
    original_content = content.dup

    # Track changes for this file
    file_changes = []

    # Pattern 1: Remove log_exception_to_rails when log_exception_to_sentry exists nearby
    # Look for log_exception_to_sentry followed by log_exception_to_rails within 10 lines
    lines = content.lines
    lines_to_remove = []

    lines.each_with_index do |line, idx|
      # If this line has log_exception_to_sentry
      if line =~ /log_exception_to_sentry/
        # Check the next 10 lines for log_exception_to_rails
        (idx + 1).upto([idx + 10, lines.length - 1].min) do |check_idx|
          if lines[check_idx] =~ /^\s*log_exception_to_rails/
            lines_to_remove << check_idx
            file_changes << {
              line: check_idx + 1,
              removed: lines[check_idx].strip
            }
          end
        end
      end

      # Also check if log_exception_to_rails comes BEFORE log_exception_to_sentry (reverse order)
      if line =~ /^\s*log_exception_to_rails/
        # Check the next 10 lines for log_exception_to_sentry
        (idx + 1).upto([idx + 10, lines.length - 1].min) do |check_idx|
          if lines[check_idx] =~ /log_exception_to_sentry/
            lines_to_remove << idx unless lines_to_remove.include?(idx)
            unless file_changes.any? { |c| c[:line] == idx + 1 }
              file_changes << {
                line: idx + 1,
                removed: lines[idx].strip
              }
            end
          end
        end
      end
    end

    # Remove duplicates and sort in reverse order so we can remove from bottom up
    lines_to_remove = lines_to_remove.uniq.sort.reverse

    # Remove the lines
    lines_to_remove.each do |idx|
      lines.delete_at(idx)
    end

    modified_content = lines.join

    if modified_content == original_content
      puts "○ NO CHANGES: #{relative_path}"
    else
      if @dry_run
        puts "📋 WOULD MODIFY: #{relative_path}"
        file_changes.each do |change|
          puts "   Line #{change[:line]}: #{change[:removed]}"
        end
      else
        # Backup original
        backup_path = File.join(@backup_dir, relative_path)
        FileUtils.mkdir_p(File.dirname(backup_path))
        FileUtils.cp(full_path, backup_path)

        # Write modified content
        File.write(full_path, modified_content)

        puts "✓ MODIFIED: #{relative_path}"
        file_changes.each do |change|
          puts "   Removed line #{change[:line]}: #{change[:removed]}"
        end
      end

      @changes << {
        file: relative_path,
        changes: file_changes
      }
    end

    puts
  end

  def print_summary # rubocop:disable Metrics/MethodLength
    puts '=' * 80
    puts 'SUMMARY'
    puts '=' * 80
    puts "Total files checked: #{TARGET_FILES.length}"
    puts "Files modified: #{@changes.length}"
    puts "Total log statements removed: #{@changes.sum { |c| c[:changes].length }}"

    if @dry_run
      puts "\n⚠  DRY RUN MODE - No actual changes were made"
      puts 'Run without --dry-run to apply changes'
    else
      puts "\n✓ Changes applied successfully"
      puts "✓ Backups saved to: #{@backup_dir}"
      puts "\nNext steps:"
      puts '1. Review the changes with: git diff'
      puts '2. Run tests: bundle exec rspec'
      puts "3. If issues occur, restore from: #{@backup_dir}"
    end

    if @changes.any?
      puts "\n#{'=' * 80}"
      puts 'CHANGED FILES:'
      puts '=' * 80
      @changes.each do |change|
        puts "  #{change[:file]} (#{change[:changes].length} lines removed)"
      end
    end

    puts '=' * 80
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts 'Usage: ruby remove_duplicate_rails_logging.rb <vets-api-root-path> [--dry-run]'
    puts ''
    puts 'Examples:'
    puts '  ruby remove_duplicate_rails_logging.rb /path/to/vets-api --dry-run'
    puts '  ruby remove_duplicate_rails_logging.rb /path/to/vets-api'
    exit 1
  end

  root_path = ARGV[0]
  dry_run = ARGV.include?('--dry-run')

  unless Dir.exist?(root_path)
    puts "Error: Directory does not exist: #{root_path}"
    exit 1
  end

  remover = DuplicateLoggingRemover.new(root_path, dry_run:)
  remover.run
end
