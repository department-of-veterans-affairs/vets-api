# frozen_string_literal: true

require 'csv'
require 'stringio'

namespace :decision_reviews do
  namespace :remediation do
    # Process appeal submission error statuses
    def self.process_appeal_submissions(appeal_submission_ids, dry_run, output_buffer = nil) # rubocop:disable Metrics/MethodLength
      # Helper to log to both console and buffer
      log = lambda do |message|
        puts message
        output_buffer&.puts message
      end

      stats = {
        processed: 0,
        cleared: 0,
        errors: 0
      }

      results = {
        updates: [],
        errors: []
      }

      return { stats:, results: } if appeal_submission_ids.empty?

      log.call "\n#{'🔄 ' * 40}"
      log.call 'STEP 1: CLEARING APPEAL SUBMISSION ERROR STATUSES'
      log.call '🔄 ' * 40

      appeal_submissions = AppealSubmission.where(id: appeal_submission_ids).includes(
        :saved_claim_sc,
        :saved_claim_hlr,
        :saved_claim_nod,
        :user_account
      )

      log.call "\nFound #{appeal_submissions.count} AppealSubmission records"

      appeal_submissions.each do |submission|
        stats[:processed] += 1

        begin
          saved_claim = submission.saved_claim_sc || submission.saved_claim_hlr || submission.saved_claim_nod

          if saved_claim.nil?
            error_msg = "No SavedClaim found for AppealSubmission #{submission.id}"
            log.call "  ⚠️  #{error_msg}"
            results[:errors] << { type: 'appeal', id: submission.id, error: error_msg }
            stats[:errors] += 1
            next
          end

          # Get current metadata (parse JSON string)
          if saved_claim.metadata.nil?
            log.call "\n  ⚠️  SavedClaim metadata is nil for AppealSubmission ##{submission.id}"
          end
          metadata = JSON.parse(saved_claim.metadata || '{}')
          old_status = metadata['status']

          log.call "\n  Processing AppealSubmission ##{submission.id} created at #{submission.created_at}"
          log.call "    SavedClaim: #{saved_claim.class.name} (guid: #{saved_claim.guid}) #{saved_claim.created_at}"
          log.call "    Current status: #{old_status || 'none'}"
          log.call "    Failure notification sent: #{submission.failure_notification_sent_at || 'No'}"

          # Clear error status from metadata
          if old_status == 'error'
            if dry_run
              log.call '    [DRY RUN] Would clear error status from metadata'
            else
              metadata.delete('status')
              metadata.delete('detail')
              metadata.delete('code')
              saved_claim.update!(metadata: metadata.to_json)
              stats[:cleared] += 1
              log.call '    ✅ Cleared error status from metadata'
            end

            results[:updates] << {
              appeal_submission_id: submission.id,
              saved_claim_guid: saved_claim.guid,
              saved_claim_type: saved_claim.class.name,
              old_status:,
              cleared: !dry_run
            }
          else
            log.call "    ℹ️  Status is not 'error', skipping clear (current: #{old_status})"
          end
        rescue => e
          error_msg = "Error processing AppealSubmission #{submission.id}: #{e.message}"
          log.call "  ❌ #{error_msg}"
          results[:errors] << { type: 'appeal', id: submission.id, error: error_msg, backtrace: e.backtrace.first(3) }
          stats[:errors] += 1
        end
      end

      { stats:, results: }
    end

    # Process evidence upload error statuses
    def self.process_evidence_uploads(lighthouse_upload_ids, dry_run, output_buffer = nil) # rubocop:disable Metrics/MethodLength
      # Helper to log to both console and buffer
      log = lambda do |message|
        puts message
        output_buffer&.puts message
      end

      stats = {
        processed: 0,
        cleared: 0,
        errors: 0
      }

      results = {
        updates: [],
        errors: []
      }

      return { stats:, results: } if lighthouse_upload_ids.empty?

      log.call "\n#{'🔄 ' * 40}"
      log.call 'STEP 2: CLEARING EVIDENCE UPLOAD ERROR STATUSES'
      log.call '🔄 ' * 40

      evidence_uploads = AppealSubmissionUpload.where(lighthouse_upload_id: lighthouse_upload_ids).includes(
        :appeal_submission,
        appeal_submission: %i[
          saved_claim_sc
          saved_claim_hlr
          saved_claim_nod
          user_account
        ]
      )

      log.call "\nFound #{evidence_uploads.count} AppealSubmissionUpload records"

      evidence_uploads.each do |upload|
        stats[:processed] += 1

        begin
          submission = upload.appeal_submission
          saved_claim = submission.saved_claim_sc || submission.saved_claim_hlr || submission.saved_claim_nod

          if saved_claim.nil?
            error_msg = "No SavedClaim found for AppealSubmissionUpload #{upload.id}"
            log.call "  ⚠️  #{error_msg}"
            results[:errors] << { type: 'evidence', id: upload.id, error: error_msg }
            stats[:errors] += 1
            next
          end

          # Get current metadata (parse JSON string)
          if saved_claim.metadata.nil?
            log.call "\n  ⚠️  No metadata found on the corresponding SavedClaim for Evidence Upload #{upload.id}"
          end
          metadata = JSON.parse(saved_claim.metadata || '{}')
          uploads_metadata = metadata['uploads'] || []

          log.call "\n  Processing Evidence Upload ##{upload.id}"
          log.call "    Lighthouse Upload ID: #{upload.lighthouse_upload_id}"
          log.call "    AppealSubmission: #{submission.id}"
          log.call "    SavedClaim: #{saved_claim.class.name} (guid: #{saved_claim.guid})"
          log.call "    Failure notification sent: #{upload.failure_notification_sent_at || 'No'}"

          # Find and clear error status for this specific upload
          upload_entry = uploads_metadata.find { |u| u['id'] == upload.lighthouse_upload_id }

          if upload_entry
            old_status = upload_entry['status']
            log.call "    Current upload status: #{old_status || 'none'}"

            if old_status == 'error'
              if dry_run
                log.call '    [DRY RUN] Would clear error status from upload metadata'
              else
                upload_entry.delete('status')
                upload_entry.delete('detail')
                upload_entry.delete('code')
                saved_claim.update!(metadata: metadata.to_json)
                stats[:cleared] += 1
                log.call '    ✅ Cleared error status from upload metadata'
              end

              results[:updates] << {
                upload_id: upload.id,
                lighthouse_upload_id: upload.lighthouse_upload_id,
                appeal_submission_id: submission.id,
                saved_claim_guid: saved_claim.guid,
                old_status:,
                cleared: !dry_run
              }
            else
              log.call "    ℹ️  Upload status is not 'error', skipping clear (current: #{old_status})"
            end
          else
            log.call "    ⚠️  Upload not found in metadata. Full uploads metadata: #{uploads_metadata}"
          end
        rescue => e
          error_msg = "Error processing Evidence Upload #{upload.id}: #{e.message}"
          log.call "  ❌ #{error_msg}"
          results[:errors] << { type: 'evidence', id: upload.id, error: error_msg, backtrace: e.backtrace.first(3) }
          stats[:errors] += 1
        end
      end

      { stats:, results: }
    end

    # Upload results to S3
    def self.upload_results_to_s3(content, dry_run) # rubocop:disable Metrics/MethodLength
      puts "\n#{'💾 ' * 40}"
      puts 'SAVING RESULTS TO S3'
      puts '💾 ' * 40

      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      mode = dry_run ? 'dry_run' : 'live'
      file_name = "decision_reviews_remediation_#{mode}_#{timestamp}.txt"
      s3_key_prefix = 'remediation/decision_reviews/status_clearing'

      # Write to temp file
      file_path = Rails.root.join('tmp', file_name)
      File.write(file_path, content)
      puts "\n✅ File written to: #{file_path}"
      puts "   File size: #{File.size(file_path)} bytes"

      # Upload to S3
      begin
        s3_resource = Aws::S3::Resource.new(
          region: Settings.reports.aws.region,
          access_key_id: Settings.reports.aws.access_key_id,
          secret_access_key: Settings.reports.aws.secret_access_key
        )

        s3_key = "#{s3_key_prefix}/#{file_name}"

        obj = s3_resource.bucket(Settings.reports.aws.bucket).object(s3_key)
        obj.put(body: File.open(file_path, 'rb'), content_type: 'text/plain')

        puts "\n✅ File uploaded to S3:"
        puts "   Bucket: #{Settings.reports.aws.bucket}"
        puts "   Key: #{s3_key}"
        puts "   Region: #{Settings.reports.aws.region}"

        puts "\n📝 To delete the S3 file later, run in Rails console:"
        puts "   s3_resource = Aws::S3::Resource.new(region: '#{Settings.reports.aws.region}', " \
             'access_key_id: Settings.reports.aws.access_key_id, ' \
             'secret_access_key: Settings.reports.aws.secret_access_key)'
        puts "   obj = s3_resource.bucket('#{Settings.reports.aws.bucket}').object('#{s3_key}')"
        puts '   obj.delete'

        puts "\n📝 To delete the local file, run:"
        puts "   File.delete('#{file_path}')"
      rescue => e
        puts "\n❌ Error uploading to S3: #{e.class.name} - #{e.message}"
        puts "   File is still available locally at: #{file_path}"
        puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
      end

      puts "\n#{'=' * 80}"
    end

    # Shared method to clear error statuses
    def self.clear_error_statuses(appeal_submission_ids:, lighthouse_upload_ids:, dry_run: false, upload_to_s3: true) # rubocop:disable Metrics/MethodLength
      # Create output buffer to capture all output
      output_buffer = StringIO.new

      # Helper to log to both console and buffer
      log = lambda do |message|
        puts message
        output_buffer.puts message
      end

      log.call "\n#{'=' * 80}"
      log.call 'DECISION REVIEWS REMEDIATION - CLEAR RECOVERED STATUSES'
      log.call '=' * 80
      log.call "Started at: #{Time.current}"
      log.call "Dry run mode: #{dry_run ? 'ENABLED (no changes will be made)' : 'DISABLED'}"
      log.call "Appeal Submission IDs to process: #{appeal_submission_ids.count}"
      log.call "Evidence Upload IDs to process: #{lighthouse_upload_ids.count}"
      log.call '=' * 80

      if appeal_submission_ids.empty? && lighthouse_upload_ids.empty?
        log.call "\n❌ ERROR: No appeal submission IDs or lighthouse upload IDs provided"
        return
      end

      # Process appeal submissions
      appeal_result = process_appeal_submissions(appeal_submission_ids, dry_run, output_buffer)

      # Process evidence uploads
      evidence_result = process_evidence_uploads(lighthouse_upload_ids, dry_run, output_buffer)

      # Combine results
      all_errors = appeal_result[:results][:errors] + evidence_result[:results][:errors]

      # Print summary
      log.call "\n#{'📊 ' * 40}"
      log.call 'STATUS CLEARING COMPLETE'
      log.call '📊 ' * 40
      log.call "\nAppeal Submissions:"
      log.call "  Processed: #{appeal_result[:stats][:processed]}"
      log.call "  Error statuses cleared: #{appeal_result[:stats][:cleared]}"
      log.call "  Errors encountered: #{appeal_result[:stats][:errors]}"

      log.call "\nEvidence Uploads:"
      log.call "  Processed: #{evidence_result[:stats][:processed]}"
      log.call "  Error statuses cleared: #{evidence_result[:stats][:cleared]}"
      log.call "  Errors encountered: #{evidence_result[:stats][:errors]}"

      if all_errors.any?
        log.call "\n⚠️  Errors encountered during processing:"
        all_errors.each_with_index do |error, i|
          log.call "\n  Error ##{i + 1}:"
          log.call "    Type: #{error[:type]}"
          log.call "    ID: #{error[:id]}"
          log.call "    Message: #{error[:error]}"
        end
      end

      log.call "\nFinished at: #{Time.current}"
      log.call '=' * 80

      if dry_run
        log.call "\n⚠️  DRY RUN MODE - No changes were made to the database"
        log.call 'Run without DRY_RUN=true to apply changes'
      end

      # Upload to S3 if enabled
      upload_results_to_s3(output_buffer.string, dry_run) if upload_to_s3
    end

    desc 'Clear error statuses for recovered submissions'
    task clear_recovered_statuses: :environment do
      # Configuration
      appeal_submission_ids = ENV['APPEAL_SUBMISSION_IDS']&.split(',')&.map(&:to_i) || []
      lighthouse_upload_ids = ENV['LIGHTHOUSE_UPLOAD_IDS']&.split(',')&.map(&:strip) || []
      dry_run = ENV['DRY_RUN'] == 'true'

      if appeal_submission_ids.empty? && lighthouse_upload_ids.empty?
        puts "\n❌ ERROR: No appeal submission IDs or lighthouse upload IDs provided"
        puts "\nUsage:"
        puts '  # Clear appeal submission errors'
        puts "  APPEAL_SUBMISSION_IDS='123,456,789' rake decision_reviews:remediation:clear_recovered_statuses"
        puts ''
        puts '  # Clear evidence upload errors'
        puts "  LIGHTHOUSE_UPLOAD_IDS='uuid1,uuid2,uuid3' rake decision_reviews:remediation:clear_recovered_statuses"
        puts ''
        puts '  # Dry run mode (no changes, just preview)'
        puts "  DRY_RUN=true APPEAL_SUBMISSION_IDS='123,456' rake decision_reviews:remediation:clear_recovered_statuses"
        exit 1
      end

      clear_error_statuses(
        appeal_submission_ids:,
        lighthouse_upload_ids:,
        dry_run:
      )
    end

    desc 'One-time task: Clear error statuses for specific recovered submissions (November 2025)'
    task clear_november_2025_recovered_statuses: :environment do
      # Hardcoded list of appeal submission IDs that have recovered
      appeal_submission_ids = [
        # Add your appeal submission IDs here
        # Example: 12345, 67890, 11111
      ]

      # Hardcoded list of lighthouse upload IDs that have recovered
      lighthouse_upload_ids = [
        # Add your lighthouse upload IDs here
        # Example: 'uuid-1234-5678', 'uuid-abcd-efgh'
      ]

      dry_run = ENV['DRY_RUN'] == 'true'

      puts "\n#{'🔧 ' * 40}"
      puts 'ONE-TIME TASK: November 2025 Recovered Submissions'
      puts '🔧 ' * 40
      puts "This task will clear error statuses for #{appeal_submission_ids.count} appeal submissions"
      puts "and #{lighthouse_upload_ids.count} evidence uploads that have been confirmed as recovered."
      puts '🔧 ' * 40

      if appeal_submission_ids.empty? && lighthouse_upload_ids.empty?
        puts "\n❌ ERROR: No IDs are hardcoded in this task"
        puts 'Please edit the task file to add appeal submission IDs or lighthouse upload IDs'
        exit 1
      end

      clear_error_statuses(
        appeal_submission_ids:,
        lighthouse_upload_ids:,
        dry_run:
      )
    end

    desc 'Send follow-up emails for recovered submissions that had failure notifications'
    task send_recovery_emails: :environment do
      # Configuration
      appeal_submission_ids = ENV['APPEAL_SUBMISSION_IDS']&.split(',')&.map(&:to_i) || []
      vanotify_template_id = ENV.fetch('VANOTIFY_TEMPLATE_ID', nil)
      dry_run = ENV['DRY_RUN'] == 'true'

      puts "\n#{'=' * 80}"
      puts 'DECISION REVIEWS REMEDIATION - SEND RECOVERY EMAILS'
      puts '=' * 80
      puts "Started at: #{Time.current}"
      puts "Dry run mode: #{dry_run ? 'ENABLED (no emails will be sent)' : 'DISABLED'}"
      puts "Appeal Submission IDs to process: #{appeal_submission_ids.count}"
      puts '=' * 80

      if appeal_submission_ids.empty?
        puts "\n❌ ERROR: No appeal submission IDs provided"
        exit 1
      end

      if vanotify_template_id.blank?
        puts "\n❌ ERROR: VA Notify template ID not provided"
        exit 1
      end

      stats = {
        processed: 0,
        sent: 0,
        skipped: 0,
        errors: 0
      }

      results = {
        emails_sent: [],
        skipped: [],
        errors: []
      }

      puts "\n#{'📧 ' * 40}"
      puts 'SENDING RECOVERY EMAILS'
      puts '📧 ' * 40

      submissions = AppealSubmission.where(id: appeal_submission_ids).includes(
        :saved_claim_sc,
        :saved_claim_hlr,
        :saved_claim_nod,
        :user_account
      )

      puts "\nFound #{submissions.count} AppealSubmission records"

      submissions.each do |submission|
        stats[:processed] += 1

        begin
          # Only send email if failure notification was previously sent
          if submission.failure_notification_sent_at.blank?
            stats[:skipped] += 1
            skip_msg = 'No failure notification was sent'
            puts "\n  ⚠️  AppealSubmission ##{submission.id}: #{skip_msg}"
            results[:skipped] << { id: submission.id, reason: skip_msg }
            next
          end

          saved_claim = submission.saved_claim_sc || submission.saved_claim_hlr || submission.saved_claim_nod
          unless saved_claim
            stats[:skipped] += 1
            skip_msg = 'No SavedClaim found'
            puts "\n  ⚠️  AppealSubmission ##{submission.id}: #{skip_msg}"
            results[:skipped] << { id: submission.id, reason: skip_msg }
            next
          end

          # Get email address
          email_address = submission.current_email_address
          if email_address.blank?
            stats[:skipped] += 1
            skip_msg = 'No email address available'
            puts "\n  ⚠️  AppealSubmission ##{submission.id}: #{skip_msg}"
            results[:skipped] << { id: submission.id, reason: skip_msg }
            next
          end

          # Get user's first name from MPI profile
          mpi_profile = submission.get_mpi_profile
          first_name = mpi_profile&.given_names&.first || 'Veteran'

          # Get submission date
          submission_date = saved_claim.created_at.strftime('%B %d, %Y')

          puts "\n  Processing AppealSubmission ##{submission.id}"
          puts "    Created at: #{submission.created_at}"
          puts "    Email: #{email_address}"
          puts "    First name: #{first_name}"
          puts "    Submission date: #{submission_date}"
          puts "    Failure notification sent: #{submission.failure_notification_sent_at}"

          if dry_run
            puts '    [DRY RUN] Would send recovery email via VA Notify'
            stats[:sent] += 1
            results[:emails_sent] << {
              id: submission.id,
              email: email_address,
              dry_run: true
            }
          else
            # Send email via VA Notify
            vanotify_service = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
            response = vanotify_service.send_email(
              email_address:,
              template_id: vanotify_template_id,
              personalisation: {
                'first_name' => first_name,
                'submission_date' => submission_date
              }
            )

            notification_id = response['id']
            stats[:sent] += 1
            puts "    ✅ Email sent successfully (notification ID: #{notification_id})"

            results[:emails_sent] << {
              id: submission.id,
              email: email_address,
              notification_id:
            }
          end
        rescue => e
          stats[:errors] += 1
          error_msg = "Error sending email for AppealSubmission #{submission.id}: #{e.message}"
          puts "  ❌ #{error_msg}"
          results[:errors] << {
            id: submission.id,
            error: error_msg,
            backtrace: e.backtrace.first(3)
          }
        end
      end

      # Summary
      puts "\n #{'📊 ' * 40}"
      puts 'EMAIL SENDING COMPLETE'
      puts '📊 ' * 40
      puts "\n  Processed: #{stats[:processed]}"
      puts "  Emails sent: #{stats[:sent]}"
      puts "  Skipped: #{stats[:skipped]}"
      puts "  Errors: #{stats[:errors]}"

      if results[:skipped].any?
        puts "\n⚠️  Skipped submissions:"
        results[:skipped].each do |skip|
          puts "    AppealSubmission #{skip[:id]}: #{skip[:reason]}"
        end
      end

      if results[:errors].any?
        puts "\n❌ Errors encountered:"
        results[:errors].each_with_index do |error, i|
          puts "\n  Error ##{i + 1}:"
          puts "    AppealSubmission ID: #{error[:id]}"
          puts "    Message: #{error[:error]}"
        end
      end

      puts "\nFinished at: #{Time.current}"
      puts '=' * 80

      if dry_run
        puts "\n⚠️  DRY RUN MODE - No emails were sent"
        puts 'Run without DRY_RUN=true to send emails'
      end
    end
  end
end
