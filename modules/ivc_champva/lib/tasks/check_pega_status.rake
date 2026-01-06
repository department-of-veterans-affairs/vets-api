# frozen_string_literal: true

require 'pega_api/client'

namespace :ivc_champva do
  desc 'Check Pega processing status for given form UUIDs (or auto-detect missing statuses if none provided)'
  task check_pega_status: :environment do
    puts '=' * 80
    puts 'IVC CHAMPVA PEGA STATUS CHECK TASK'
    puts '=' * 80

    # Parse environment variables or get missing UUIDs automatically
    form_uuids_input = ENV['FORM_UUIDS']
    
    if form_uuids_input.blank?
      puts 'No FORM_UUIDS provided - automatically retrieving forms with missing pega_status...'
      puts 'Getting forms with missing pega_status (ignoring submissions from last minute)...'
      
      cleanup_util = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
      batches = cleanup_util.get_missing_statuses(silent: true, ignore_last_minute: true)
      
      if batches.empty?
        puts 'No forms found with missing pega_status.'
        puts 'Task completed - nothing to check!'
        form_uuids = []
      else
        form_uuids = batches.keys
        puts "Found #{form_uuids.count} form UUIDs with missing pega_status"
      end
      
    else
      form_uuids = form_uuids_input.split(',').map(&:strip).reject(&:blank?)
      
      if form_uuids.empty?
        puts 'ERROR: No valid form UUIDs provided'
        raise 'No valid form UUIDs provided'
      end
      
      puts "Form UUIDs: #{form_uuids.count} provided via FORM_UUIDS"
    end
    # Only proceed if we have UUIDs to process
    if form_uuids.any?
      puts '-' * 80

      # Initialize tracking variables
      pega_api_client = IvcChampva::PegaApi::Client.new
      unprocessed_files = []
      api_errors = []
      total_files_checked = 0
      fully_processed_uuids = []

      form_uuids.each_with_index do |form_uuid, index|
      puts "\n[#{index + 1}/#{form_uuids.count}] Checking UUID: #{form_uuid}"
      
      begin
        # Find all form records for this UUID
        form_records = IvcChampvaForm.where(form_uuid: form_uuid)
        
        if form_records.empty?
          puts "  No local records found for UUID: #{form_uuid}"
          next
        end

        puts "  Found #{form_records.count} local record(s)"
        total_files_checked += form_records.count

        # Check Pega API for this UUID using the first record as representative
        representative_record = form_records.first
        pega_reports = pega_api_client.record_has_matching_report(representative_record)

        if pega_reports == false || pega_reports.empty?
          puts "  No Pega reports found for UUID: #{form_uuid}"
          form_records.each do |record|
            unprocessed_files << {
              form_uuid: record.form_uuid,
              file_name: record.file_name,
              form_id: record.id,
              created_at: record.created_at
            }
          end
        else
          puts "  Found #{pega_reports.count} Pega report(s)"
          
          # Check if counts match (same logic as MissingFormStatusJob)
          if form_records.count == pega_reports.count
            puts "  File counts match (#{form_records.count} local, #{pega_reports.count} Pega)"
            fully_processed_uuids << form_uuid
          else
            puts "  File count mismatch (#{form_records.count} local, #{pega_reports.count} Pega)"
            form_records.each do |record|
              unprocessed_files << {
                form_uuid: record.form_uuid,
                file_name: record.file_name,
                form_id: record.id,
                created_at: record.created_at,
                count_mismatch: true
              }
            end
          end
        end

      rescue IvcChampva::PegaApi::PegaApiError => e
        error_info = {
          form_uuid: form_uuid,
          error: e.message,
          timestamp: Time.current
        }
        api_errors << error_info
        puts "  Pega API Error: #{e.message}"
        Rails.logger.error "IVC CHAMPVA check_pega_status - PegaApiError for UUID #{form_uuid}: #{e.message}"
      rescue => e
        error_info = {
          form_uuid: form_uuid,
          error: e.message,
          timestamp: Time.current
        }
        api_errors << error_info
        puts "  Unexpected Error: #{e.message}"
        Rails.logger.error "IVC CHAMPVA check_pega_status - Unexpected error for UUID #{form_uuid}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    # Summary Report
    puts "\n" + '=' * 80
    puts 'SUMMARY REPORT'
    puts '=' * 80
    puts "Total UUIDs processed: #{form_uuids.count}"
    puts "Total files checked: #{total_files_checked}"
    puts "UUIDs with matching Pega reports: #{fully_processed_uuids.count}"
    puts "UUIDs with unprocessed files: #{unprocessed_files.map { |f| f[:form_uuid] }.uniq.count}"
    puts "API errors encountered: #{api_errors.count}"

    # Unprocessed Files Report
    if unprocessed_files.any?
      puts "\n" + '-' * 80
      puts 'UNPROCESSED FILES'
      puts '-' * 80
      puts format('%-38s %-25s %-10s %-20s %s', 'FORM_UUID', 'FILE_NAME', 'FORM_ID', 'CREATED_AT', 'ISSUE')
      puts '-' * 80
      
      unprocessed_files.each do |file|
        issue = file[:count_mismatch] ? 'COUNT_MISMATCH' : 'NOT_FOUND'
        created_at = file[:created_at].strftime('%Y-%m-%d %H:%M')
        puts format('%-38s %-25s %-10s %-20s %s', 
                   file[:form_uuid], 
                   file[:file_name] || 'N/A', 
                   file[:form_id], 
                   created_at,
                   issue)
      end
    end

    # API Errors Report
    if api_errors.any?
      puts "\n" + '-' * 80
      puts 'API ERRORS'
      puts '-' * 80
      puts format('%-38s %-20s %s', 'FORM_UUID', 'TIMESTAMP', 'ERROR')
      puts '-' * 80
      
      api_errors.each do |error|
        timestamp = error[:timestamp].strftime('%Y-%m-%d %H:%M:%S')
        puts format('%-38s %-20s %s', error[:form_uuid], timestamp, error[:error])
      end
      end

      # Output fully processed UUIDs for piping to update_pega_status
      if fully_processed_uuids.any?
        puts "\n" + '-' * 80
        puts 'FULLY PROCESSED UUIDs (ready for status update)'
        puts '-' * 80
        puts "Found #{fully_processed_uuids.count} UUIDs with all files processed by Pega"
        puts "These can be marked as 'Manually Processed' using:"
        puts "FORM_UUIDS=\"#{fully_processed_uuids.join(',')}\" rake ivc_champva:update_pega_status"
        puts "\nComma-separated list for FORM_UUIDS variable:"
        puts '-' * 50
        puts fully_processed_uuids.join(',')
      else
        puts "\nNo UUIDs found with all files fully processed by Pega."
      end

      puts "\nTask completed!"
    end
  end
end
