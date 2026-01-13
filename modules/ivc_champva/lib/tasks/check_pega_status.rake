# frozen_string_literal: true

require 'pega_api/client'

# Helper class to check Pega status and generate reports
class PegaStatusChecker
  def initialize
    @pega_api_client = IvcChampva::PegaApi::Client.new
    @unprocessed_files = []
    @api_errors = []
    @total_files_checked = 0
    @fully_processed_uuids = []
  end

  def run
    puts '=' * 80
    puts 'IVC CHAMPVA PEGA STATUS CHECK TASK'
    puts '=' * 80

    form_uuids = get_form_uuids
    return if form_uuids.empty?

    puts '-' * 80
    process_uuids(form_uuids)
    print_summary_report(form_uuids)
    print_unprocessed_files_report
    print_api_errors_report
    print_fully_processed_uuids_report
    puts "\nTask completed!"
  end

  private

  def get_form_uuids
    form_uuids_input = ENV.fetch('FORM_UUIDS', nil)

    if form_uuids_input.blank?
      get_missing_status_uuids
    else
      parse_provided_uuids(form_uuids_input)
    end
  end

  def get_missing_status_uuids
    puts 'No FORM_UUIDS provided - automatically retrieving forms with missing pega_status...'
    puts 'Getting forms with missing pega_status (ignoring submissions from last minute)...'

    cleanup_util = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
    batches = cleanup_util.get_missing_statuses(silent: true, ignore_last_minute: true)

    if batches.empty?
      puts 'No forms found with missing pega_status.'
      puts 'Task completed - nothing to check!'
      return []
    end

    form_uuids = batches.keys
    puts "Found #{form_uuids.count} form UUIDs with missing pega_status"
    form_uuids
  end

  def parse_provided_uuids(form_uuids_input)
    form_uuids = form_uuids_input.split(',').map(&:strip).compact_blank

    if form_uuids.empty?
      puts 'ERROR: No valid form UUIDs provided'
      raise 'No valid form UUIDs provided'
    end

    puts "Form UUIDs: #{form_uuids.count} provided via FORM_UUIDS"
    form_uuids
  end

  def process_uuids(form_uuids)
    form_uuids.each_with_index do |form_uuid, index|
      puts "\n[#{index + 1}/#{form_uuids.count}] Checking UUID: #{form_uuid}"

      begin
        process_single_uuid(form_uuid)
      rescue IvcChampva::PegaApi::PegaApiError => e
        handle_api_error(form_uuid, e, 'PegaApiError')
      rescue => e
        handle_api_error(form_uuid, e, 'Unexpected error')
      end
    end
  end

  def process_single_uuid(form_uuid)
    form_records = get_form_records(form_uuid)
    return unless form_records

    pega_processable_records = prepare_pega_records(form_records)
    return unless pega_processable_records

    process_pega_reports(pega_processable_records, form_uuid)
  end

  def get_form_records(form_uuid)
    form_records = IvcChampvaForm.where(form_uuid:)

    if form_records.empty?
      puts "  No local records found for UUID: #{form_uuid}"
      return nil
    end

    form_records
  end

  def prepare_pega_records(form_records)
    pega_processable_records = filter_pega_processable_files(form_records)

    @total_files_checked += form_records.count
    puts "  Found #{pega_processable_records.count} local record(s)"

    if pega_processable_records.empty?
      puts '  No files sent to Pega for processing'
      return nil
    end

    pega_processable_records
  end

  def process_pega_reports(pega_processable_records, form_uuid)
    representative_record = pega_processable_records.first
    pega_reports = @pega_api_client.record_has_matching_report(representative_record)

    if pega_reports == false || pega_reports.empty?
      puts "  No Pega reports found for UUID: #{form_uuid}"
      add_unprocessed_files(pega_processable_records)
    else
      puts "  Found #{pega_reports.count} Pega report(s)"
      check_file_counts(pega_processable_records, pega_reports, form_uuid)
    end
  end

  def filter_pega_processable_files(form_records)
    # Exclude VES JSON files since they're sent to VES, not Pega
    form_records.reject { |record| ves_json_file?(record.file_name) }
  end

  def ves_json_file?(file_name)
    return false if file_name.blank?

    file_name.include?('_ves.json')
  end

  def check_file_counts(form_records, pega_reports, form_uuid)
    if form_records.count == pega_reports.count
      puts "  File counts match (#{form_records.count} local, #{pega_reports.count} Pega)"
      @fully_processed_uuids << form_uuid
    else
      puts "  File count mismatch (#{form_records.count} local, #{pega_reports.count} Pega)"
      add_unprocessed_files(form_records, count_mismatch: true)
    end
  end

  def add_unprocessed_files(form_records, count_mismatch: false)
    form_records.each do |record|
      @unprocessed_files << create_unprocessed_file_entry(record, count_mismatch)
    end
  end

  def create_unprocessed_file_entry(record, count_mismatch)
    entry = {
      form_uuid: record.form_uuid,
      file_name: record.file_name,
      s3_status: record.s3_status,
      created_at: record.created_at
    }
    entry[:count_mismatch] = true if count_mismatch
    entry
  end

  def handle_api_error(form_uuid, error, error_type)
    error_info = {
      form_uuid:,
      error: error.message,
      timestamp: Time.current
    }
    @api_errors << error_info
    puts "  #{error_type}: #{error.message}"
    Rails.logger.error "IVC CHAMPVA check_pega_status - #{error_type} for UUID #{form_uuid}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error_type == 'Unexpected error'
  end

  def print_summary_report(form_uuids)
    puts "\n#{'=' * 80}\nSUMMARY REPORT\n#{'=' * 80}"
    puts "Total UUIDs processed: #{form_uuids.count}"
    puts "Total files checked: #{@total_files_checked}"
    puts "UUIDs with matching Pega reports: #{@fully_processed_uuids.count}"
    puts "UUIDs with unprocessed files: #{@unprocessed_files.map { |f| f[:form_uuid] }.uniq.count}"
    puts "API errors encountered: #{@api_errors.count}"
  end

  def print_unprocessed_files_report
    return unless @unprocessed_files.any?

    puts "\n#{'-' * 80}\nUNPROCESSED FILES\n#{'-' * 80}"
    puts format('%-38<form_uuid>s %-25<file_name>s %-12<s3_status>s %-20<created_at>s %<issue>s',
                form_uuid: 'FORM_UUID', file_name: 'FILE_NAME', s3_status: 'S3_STATUS',
                created_at: 'CREATED_AT', issue: 'ISSUE')
    puts '-' * 80

    @unprocessed_files.each do |file|
      issue = file[:count_mismatch] ? 'COUNT_MISMATCH' : 'NOT_FOUND'
      created_at = file[:created_at].strftime('%Y-%m-%d %H:%M')
      puts format('%-38<form_uuid>s %-25<file_name>s %-12<s3_status>s %-20<created_at>s %<issue>s',
                  form_uuid: file[:form_uuid],
                  file_name: file[:file_name] || 'N/A',
                  s3_status: file[:s3_status] || 'N/A',
                  created_at:,
                  issue:)
    end
  end

  def print_api_errors_report
    return unless @api_errors.any?

    puts "\n#{'-' * 80}\nAPI ERRORS\n#{'-' * 80}"
    puts format('%-38<form_uuid>s %-20<timestamp>s %<error>s',
                form_uuid: 'FORM_UUID', timestamp: 'TIMESTAMP', error: 'ERROR')
    puts '-' * 80

    @api_errors.each do |error|
      timestamp = error[:timestamp].strftime('%Y-%m-%d %H:%M:%S')
      puts format('%-38<form_uuid>s %-20<timestamp>s %<error>s',
                  form_uuid: error[:form_uuid], timestamp:, error: error[:error])
    end
  end

  def print_fully_processed_uuids_report
    if @fully_processed_uuids.any?
      puts "\n#{'-' * 80}\nFULLY PROCESSED UUIDs (ready for status update)\n#{'-' * 80}"
      puts "Found #{@fully_processed_uuids.count} UUIDs with all files processed by Pega"
      puts 'These can be marked as \'Manually Processed\' using:'
      puts "FORM_UUIDS=\"#{@fully_processed_uuids.join(',')}\" rake ivc_champva:update_pega_status"
      puts "\nComma-separated list for FORM_UUIDS variable:"
      puts '-' * 50
      puts @fully_processed_uuids.join(',')
    else
      puts "\nNo UUIDs found with all files fully processed by Pega."
    end
  end
end

namespace :ivc_champva do
  desc 'Check Pega processing status for given form UUIDs (or auto-detect missing statuses if none provided)'
  task check_pega_status: :environment do
    checker = PegaStatusChecker.new
    checker.run
  end
end
