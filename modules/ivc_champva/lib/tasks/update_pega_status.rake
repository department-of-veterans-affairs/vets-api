# frozen_string_literal: true

namespace :ivc_champva do
  desc 'Update pega_status for forms with specified UUIDs'
  task update_pega_status: :environment do
    form_uuids = ENV['FORM_UUIDS']&.split(',')&.map(&:strip) || []
    dry_run = ENV['DRY_RUN'] == 'true'

    raise 'FORM_UUIDS required - provide comma-separated list' if form_uuids.empty?

    puts '=' * 80, 'IVC CHAMPVA PEGA STATUS UPDATE TASK', '=' * 80
    puts "Mode: #{dry_run ? 'DRY RUN (no changes will be made)' : 'LIVE UPDATE'}"
    puts 'New Status: Manually Processed'
    puts "Form UUIDs: #{form_uuids.count} provided"
    puts "Batch Size: #{ENV['BATCH_SIZE']&.to_i || 100}", '-' * 80

    cleanup_util = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
    total_updated = 0
    total_forms_found = 0
    processed_uuids = []
    failed_uuids = []

    form_uuids.each_with_index do |form_uuid, index|
      puts "\n[#{index + 1}/#{form_uuids.count}] Processing UUID: #{form_uuid}"
      begin
        forms = IvcChampvaForm.where(form_uuid:)
        if forms.empty?
          puts "  WARNING: No forms found for UUID: #{form_uuid}"
          failed_uuids << { uuid: form_uuid, reason: 'No forms found' }
          next
        end

        total_forms_found += forms.count
        puts "  Found #{forms.count} form record(s)"
        puts "  Current status distribution: #{forms.group(:pega_status).count}"

        forms_with_nil_status = forms.where(pega_status: nil)
        forms_with_status = forms.where.not(pega_status: nil)

        # Log skipped forms
        forms_with_status.each do |f|
          puts "    SKIPPED form ID #{f.id} (#{f.file_name}) - already has status '#{f.pega_status}'"
        end

        # Process forms with nil status
        updated_count = forms_with_nil_status.count
        if updated_count.positive?
          if dry_run
            forms_with_nil_status.each do |f|
              puts "    [DRY RUN] Would update form ID #{f.id} (#{f.file_name}) from '#{f.pega_status}' to \
              'Manually Processed'"
            end
          else
            forms_to_update = forms_with_nil_status.map { |f| { id: f.id, file_name: f.file_name } }
            cleanup_util.manually_process_batch(forms_with_nil_status)
            forms_to_update.each do |f|
              puts "    Updated form ID #{f[:id]} (#{f[:file_name]}) from 'nil' to 'Manually Processed'"
            end
          end
        end

        total_updated += updated_count
        processed_uuids << form_uuid
        puts "  Processed #{updated_count} forms for UUID: #{form_uuid}"
      rescue => e
        puts "  ERROR processing UUID #{form_uuid}: #{e.message}"
        Rails.logger.error "IVC CHAMPVA Pega Status Update Error for UUID #{form_uuid}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        failed_uuids << { uuid: form_uuid, reason: e.message }
      end
    end

    # Summary
    puts "\n#{'=' * 80}\nSUMMARY\n#{'=' * 80}"
    puts "Total UUIDs processed: #{processed_uuids.count}/#{form_uuids.count}"
    puts "Total forms found: #{total_forms_found}"
    puts "Total forms #{dry_run ? 'that would be updated' : 'updated'}: #{total_updated}"
    puts "Failed UUIDs: #{failed_uuids.count}"

    if failed_uuids.any?
      puts "\nFAILED UUIDS:"
      failed_uuids.each { |failure| puts "  - #{failure[:uuid]}: #{failure[:reason]}" }
    end
    if processed_uuids.any?
      puts "\nSUCCESSFULLY PROCESSED UUIDS:"
      processed_uuids.each { |uuid| puts "  - #{uuid}" }
    end
    puts "\nTask completed #{dry_run ? '(DRY RUN)' : 'successfully'}!"
  end
end
