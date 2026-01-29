# frozen_string_literal: true

require 'ivc_champva/monitor'

# rubocop:disable Metrics/BlockLength
namespace :ivc_champva do
  desc 'Send failure emails for 10-7959A forms with only a single record per form_uuid (Jan 20-21, 2026)'
  task send_cva_remediation_emails: :environment do
    dry_run = ENV['DRY_RUN'] == 'true'
    page_size = (ENV['PAGE_SIZE'] || 50).to_i
    page = (ENV['PAGE'] || 0).to_i

    puts '=' * 80
    puts 'IVC CHAMPVA CVA REMEDIATION EMAIL SENDER'
    puts '[DRY RUN MODE - No emails will be sent, no DB updates will be made]' if dry_run
    puts "[PAGE: #{page}, PAGE_SIZE: #{page_size}] (records #{page * page_size} to #{((page + 1) * page_size) - 1})"
    puts '=' * 80
    puts 'Finding affected 10-7959A forms from Jan 20-21, 2026...'
    puts '-' * 80

    start_date = Date.new(2026, 1, 20).beginning_of_day
    end_date = Date.new(2026, 1, 21).end_of_day

    # Find form_uuids that have exactly 1 record (claim form only, no supporting docs/VES JSON)
    single_record_uuids = IvcChampvaForm
                          .where(form_number: '10-7959A')
                          .where(created_at: start_date..end_date)
                          .group(:form_uuid)
                          .having('COUNT(*) = 1')
                          .order(:form_uuid)
                          .pluck(:form_uuid)

    total_count = single_record_uuids.count
    total_pages = (total_count.to_f / page_size).ceil

    if single_record_uuids.empty?
      puts 'No affected forms found.'
      next
    end

    puts "Total matching form_uuids: #{total_count} (#{total_pages} pages of #{page_size})"

    # Apply pagination
    offset = page * page_size
    single_record_uuids = single_record_uuids.slice(offset, page_size) || []

    if single_record_uuids.empty?
      puts "No records on page #{page}. Valid pages: 0 to #{total_pages - 1}"
      next
    end

    all_forms = IvcChampvaForm.where(form_uuid: single_record_uuids).to_a

    # Deduplicate by unique name/email combo to avoid sending multiple emails to the same person
    # Dedeuping by both name AND email in case the same email was used by separate users - we want to notify
    # all users in that case.
    forms = all_forms.uniq { |f| [f.first_name, f.last_name, f.email] }

    puts "Found #{all_forms.count} affected form records"
    puts "Deduplicated to #{forms.count} unique recipients (by name/email)"
    puts '-' * 80

    monitor = IvcChampva::Monitor.new
    notify_client = VaNotify::Service.new(Settings.vanotify.services.ivc_champva.api_key) unless dry_run
    success_count = 0
    failure_count = 0
    skipped_count = 0

    forms.each_with_index do |form, index|
      # Rate limiting: sleep every 15 emails to avoid overwhelming VANotify
      # From gist: https://gist.github.com/michaelclement/9d775dea28be443d62f9267b53999abe
      if !dry_run && index.positive? && (index % 15).zero?
        puts 'Rate limiting - sleeping 1 second...'
        sleep 1
      end

      template_id = '10-7959A-FAILURE'
      additional_context = { form_id: form.form_number, form_uuid: form.form_uuid }

      form_data = {
        email: form.email,
        first_name: form.first_name,
        last_name: form.last_name,
        form_number: form.form_number,
        file_count: nil,
        pega_status: form.pega_status,
        date_submitted: form.created_at.strftime('%B %d, %Y'),
        template_id:,
        form_uuid: form.form_uuid
      }

      if dry_run
        puts "#{index + 1}/#{forms.size} - [DRY RUN] Would send email for #{form.form_uuid} to #{form.email}"
        success_count += 1
        next
      end

      begin
        ActiveRecord::Base.transaction do
          # Use synchronous email sending for accurate success/failure tracking (IvcChampva::Email.send_email is async)
          notify_client.send_email(
            email_address: form_data[:email],
            template_id: IvcChampva::Email::EMAIL_TEMPLATE_MAP[template_id],
            personalisation: form_data
          )

          IvcChampvaForm.where(form_uuid: form.form_uuid).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
          monitor.track_missing_status_email_sent(form.form_number)
          puts "#{index + 1}/#{forms.size} - Sent email for #{form.form_uuid} to #{form.email}"
          success_count += 1
        end
      rescue => e
        monitor.log_silent_failure(additional_context)
        puts "#{index + 1}/#{forms.size} - Failed to send email for #{form.form_uuid}: #{e.message}"
        failure_count += 1
      end
    end

    puts '=' * 80
    puts dry_run ? 'DRY RUN COMPLETE - No emails sent, no DB updates made' : 'SUMMARY'
    puts '=' * 80
    puts "Page #{page} of #{total_pages - 1} (0-indexed)"
    puts "Emails #{dry_run ? 'that would be sent' : 'sent successfully'}: #{success_count}"
    puts "Emails failed: #{failure_count}"
    puts "Skipped (already sent): #{skipped_count}"
    puts "Total unique recipients this page: #{forms.size}"
    puts "Next page: PAGE=#{page + 1} PAGE_SIZE=#{page_size}" if page + 1 < total_pages
  end
end
# rubocop:enable Metrics/BlockLength
