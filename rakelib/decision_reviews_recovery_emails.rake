# frozen_string_literal: true

require 'csv'
require 'stringio'
require 'decision_reviews/v1/constants'

namespace :decision_reviews do
  namespace :remediation do
    # Process evidence recovery emails
    def self.process_evidence_recovery_emails(lighthouse_upload_ids, dry_run, output_buffer = nil) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      # Helper to log to both console and buffer
      log = lambda do |message|
        puts message
        output_buffer&.puts message
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

      return { stats:, results: } if lighthouse_upload_ids.empty?

      log.call "\n#{'📧 ' * 40}"
      log.call 'SENDING EVIDENCE RECOVERY EMAILS'
      log.call '📧 ' * 40

      # Get template ID from settings
      template_id = Settings.vanotify.services.benefits_decision_review.template_id.evidence_recovery_email

      if template_id.blank?
        log.call "\n❌ ERROR: Evidence recovery email template ID not configured"
        log.call 'Please set: vanotify__services__benefits_decision_review__template_id__evidence_recovery_email'
        return { stats:, results: }
      end

      log.call "Template ID: #{template_id}"

      evidence_uploads = AppealSubmissionUpload.where(lighthouse_upload_id: lighthouse_upload_ids).includes(
        appeal_submission: %i[saved_claim_sc saved_claim_hlr saved_claim_nod user_account]
      )

      log.call "\nFound #{evidence_uploads.count} AppealSubmissionUpload records"

      evidence_uploads.each do |upload|
        stats[:processed] += 1

        begin
          # Check if failure notification was sent
          if upload.failure_notification_sent_at.blank?
            stats[:skipped] += 1
            log.call "\n  ⚠️  Upload ##{upload.id}: No failure notification sent - skipping"
            results[:skipped] << { id: upload.id, reason: 'No failure notification sent' }
            next
          end

          # Get associated submission
          submission = upload.appeal_submission
          unless submission
            stats[:skipped] += 1
            log.call "\n  ⚠️  Upload ##{upload.id}: No AppealSubmission found - skipping"
            results[:skipped] << { id: upload.id, reason: 'No AppealSubmission found' }
            next
          end

          # Get email address
          email_address = submission.current_email_address
          if email_address.blank?
            stats[:skipped] += 1
            log.call "\n  ⚠️  Upload ##{upload.id}: No email address - skipping"
            results[:skipped] << { id: upload.id, reason: 'No email address' }
            next
          end

          # Get user info
          mpi_profile = submission.get_mpi_profile
          first_name = mpi_profile&.given_names&.first || 'Veteran'

          # Format dates
          failure_notification_date = upload.failure_notification_sent_at.strftime('%B %d, %Y')
          date_submitted = upload.created_at.strftime('%B %d, %Y')

          # Get filename
          filename = upload.masked_attachment_filename || 'your evidence'

          log.call "\n  Processing Upload ##{upload.id}"
          log.call "    First name: #{first_name}"
          log.call "    Filename: #{filename}"
          log.call "    Date submitted: #{date_submitted}"
          log.call "    Failure notification sent: #{failure_notification_date}"

          if dry_run
            log.call '    [DRY RUN] Would send evidence recovery email'
            stats[:sent] += 1
            results[:emails_sent] << { id: upload.id, dry_run: true }
          else
            # Send email via VA Notify
            appeal_type = submission.type_of_appeal
            reference = "#{appeal_type}-evidence-recovery-#{upload.lighthouse_upload_id}"

            callback_options = {
              callback_metadata: {
                email_type: :evidence_recovery,
                service_name: DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type],
                function: 'recovered evidence upload follow up email',
                submitted_appeal_uuid: submission.submitted_appeal_uuid,
                lighthouse_upload_id: upload.lighthouse_upload_id,
                email_template_id: template_id,
                reference:,
                statsd_tags: ["service:#{DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}",
                              'function:evidence_recovery_email']
              }
            }

            vanotify_service = VaNotify::Service.new(
              Settings.vanotify.services.benefits_decision_review.api_key,
              callback_options
            )

            vanotify_service.send_email(
              email_address:,
              template_id:,
              personalisation: {
                'first_name' => first_name,
                'failure_notification_sent_at' => failure_notification_date,
                'filename' => filename,
                'date_submitted' => date_submitted
              }
            )

            stats[:sent] += 1
            log.call '    ✅ Email sent'

            results[:emails_sent] << { id: upload.id }
          end
        rescue => e
          stats[:errors] += 1
          error_msg = e.message.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, '[EMAIL_REDACTED]')
          log.call "  ❌ Error for Upload #{upload.id}: #{error_msg}"
          results[:errors] << { id: upload.id, error: error_msg }
        end
      end

      { stats:, results: }
    end

    # Process form recovery emails
    def self.process_form_recovery_emails(appeal_submission_ids, dry_run, output_buffer = nil) # rubocop:disable Metrics/MethodLength
      # Helper to log to both console and buffer
      log = lambda do |message|
        puts message
        output_buffer&.puts message
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

      return { stats:, results: } if appeal_submission_ids.empty?

      log.call "\n#{'📧 ' * 40}"
      log.call 'SENDING FORM RECOVERY EMAILS'
      log.call '📧 ' * 40

      # Get template ID from settings
      template_id = Settings.vanotify.services.benefits_decision_review.template_id.form_recovery_email

      if template_id.blank?
        log.call "\n❌ ERROR: Form recovery email template ID not configured"
        log.call 'Please set: vanotify__services__benefits_decision_review__template_id__form_recovery_email'
        return { stats:, results: }
      end

      log.call "Template ID: #{template_id}"

      form_submissions = AppealSubmission.where(id: appeal_submission_ids)
                                         .includes(:saved_claim_sc, :saved_claim_hlr, :saved_claim_nod, :user_account)

      log.call "\nFound #{form_submissions.count} AppealSubmission records"

      form_submissions.each do |submission|
        stats[:processed] += 1

        begin
          # Check if failure notification was sent
          if submission.failure_notification_sent_at.blank?
            stats[:skipped] += 1
            log.call "\n  ⚠️  Submission ##{submission.id}: No failure notification sent - skipping"
            results[:skipped] << { id: submission.id, reason: 'No failure notification sent' }
            next
          end

          # Get email address
          email_address = submission.current_email_address
          if email_address.blank?
            stats[:skipped] += 1
            log.call "\n  ⚠️  Submission ##{submission.id}: No email address - skipping"
            results[:skipped] << { id: submission.id, reason: 'No email address' }
            next
          end

          # Get user info
          mpi_profile = submission.get_mpi_profile
          first_name = mpi_profile&.given_names&.first || 'Veteran'

          # Get decision review type
          decision_review_type, decision_review_form_id = case submission.type_of_appeal
                                                          when 'HLR' then ['Higher-Level Review', 'VA Form 20-0996']
                                                          when 'SC' then ['Supplemental Claim', 'VA Form 20-0995']
                                                          when 'NOD' then ['Notice of Disagreement (Board Appeal)',
                                                                           'VA Form 10182']
                                                          else ['Decision Review', 'Decision Review Form']
                                                          end

          # Format dates
          failure_notification_date = submission.failure_notification_sent_at.strftime('%B %d, %Y')
          date_submitted = submission.created_at.strftime('%B %d, %Y')

          log.call "\n  Processing Submission ##{submission.id}"
          log.call "    First name: #{first_name}"
          log.call "    Decision review type: #{decision_review_type}"
          log.call "    Form ID: #{decision_review_form_id}"
          log.call "    Date submitted: #{date_submitted}"
          log.call "    Failure notification sent: #{failure_notification_date}"

          if dry_run
            log.call '    [DRY RUN] Would send form recovery email'
            stats[:sent] += 1
            results[:emails_sent] << { id: submission.id, dry_run: true }
          else
            # Send email via VA Notify
            appeal_type = submission.type_of_appeal
            reference = "#{appeal_type}-form-recovery-#{submission.submitted_appeal_uuid}"

            callback_options = {
              callback_metadata: {
                email_type: :form_recovery,
                service_name: DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type],
                function: 'recovered form submission follow up email',
                submitted_appeal_uuid: submission.submitted_appeal_uuid,
                email_template_id: template_id,
                reference:,
                statsd_tags: ["service:#{DecisionReviews::V1::APPEAL_TYPE_TO_SERVICE_MAP[appeal_type]}",
                              'function:form_recovery_email']
              }
            }

            vanotify_service = VaNotify::Service.new(
              Settings.vanotify.services.benefits_decision_review.api_key,
              callback_options
            )

            vanotify_service.send_email(
              email_address:,
              template_id:,
              personalisation: {
                'first_name' => first_name,
                'decision_review_type' => decision_review_type,
                'decision_review_form_id' => decision_review_form_id,
                'date_submitted' => date_submitted
              }
            )

            stats[:sent] += 1
            log.call '    ✅ Email sent'

            results[:emails_sent] << { id: submission.id }
          end
        rescue => e
          stats[:errors] += 1
          error_msg = e.message.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, '[EMAIL_REDACTED]')
          log.call "  ❌ Error for Submission #{submission.id}: #{error_msg}"
          results[:errors] << { id: submission.id, error: error_msg }
        end
      end

      { stats:, results: }
    end

    # Upload results to S3
    def self.upload_email_results_to_s3(content, dry_run) # rubocop:disable Metrics/MethodLength
      puts "\n#{'💾 ' * 40}"
      puts 'SAVING RESULTS TO S3'
      puts '💾 ' * 40

      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      mode = dry_run ? 'dry_run' : 'live'
      file_name = "decision_reviews_recovery_emails_#{mode}_#{timestamp}.txt"
      s3_key_prefix = 'remediation/decision_reviews/recovery_emails'

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
        obj.put(body: File.read(file_path), content_type: 'text/plain')

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
        puts "\n❌ Error uploading to S3: #{e.class} - #{e.message}"
        puts "   File is still available locally at: #{file_path}"
        puts "   Backtrace: #{e.backtrace.first(3)}"
      end

      puts "\n#{'=' * 80}"
    end

    desc 'Send follow-up emails for recovered evidence uploads that had failure notifications'
    task send_evidence_recovery_emails: :environment do
      lighthouse_upload_ids = ENV.fetch('LIGHTHOUSE_UPLOAD_IDS', '').split(',').map(&:strip)
      dry_run = ENV['DRY_RUN'] == 'true'
      upload_to_s3 = ENV.fetch('UPLOAD_TO_S3', 'true') == 'true'

      if lighthouse_upload_ids.empty?
        puts "\n❌ ERROR: No lighthouse upload IDs provided"
        exit 1
      end

      # Create output buffer to capture all output
      output_buffer = StringIO.new

      # Process evidence recovery emails
      result = process_evidence_recovery_emails(lighthouse_upload_ids, dry_run, output_buffer)

      # Print summary
      puts "\n#{'📊 ' * 40}"
      puts 'EMAIL SENDING COMPLETE'
      puts '📊 ' * 40
      puts "\nEvidence Recovery Emails:"
      puts "  Processed: #{result[:stats][:processed]}"
      puts "  Sent: #{result[:stats][:sent]}"
      puts "  Skipped: #{result[:stats][:skipped]}"
      puts "  Errors: #{result[:stats][:errors]}"
      puts "\nFinished at: #{Time.current}"
      puts '=' * 80

      if dry_run
        puts "\n⚠️  DRY RUN MODE - No emails were sent"
        puts 'Run without DRY_RUN=true to send emails'
      end

      # Upload to S3 if enabled
      upload_email_results_to_s3(output_buffer.string, dry_run) if upload_to_s3
    end

    desc 'Send follow-up emails for recovered form submissions that had failure notifications'
    task send_form_recovery_emails: :environment do
      appeal_submission_ids = ENV.fetch('APPEAL_SUBMISSION_IDS', '').split(',').map(&:strip).map(&:to_i)
      dry_run = ENV['DRY_RUN'] == 'true'
      upload_to_s3 = ENV.fetch('UPLOAD_TO_S3', 'true') == 'true'

      if appeal_submission_ids.empty?
        puts "\n❌ ERROR: No appeal submission IDs provided"
        exit 1
      end

      # Create output buffer to capture all output
      output_buffer = StringIO.new

      # Process form recovery emails
      result = process_form_recovery_emails(appeal_submission_ids, dry_run, output_buffer)

      # Print summary
      puts "\n#{'📊 ' * 40}"
      puts 'EMAIL SENDING COMPLETE'
      puts '📊 ' * 40
      puts "\nForm Recovery Emails:"
      puts "  Processed: #{result[:stats][:processed]}"
      puts "  Sent: #{result[:stats][:sent]}"
      puts "  Skipped: #{result[:stats][:skipped]}"
      puts "  Errors: #{result[:stats][:errors]}"
      puts "\nFinished at: #{Time.current}"
      puts '=' * 80

      if dry_run
        puts "\n⚠️  DRY RUN MODE - No emails were sent"
        puts 'Run without DRY_RUN=true to send emails'
      end

      # Upload to S3 if enabled
      upload_email_results_to_s3(output_buffer.string, dry_run) if upload_to_s3
    end

    desc 'One-time task: Send recovery emails for specific recovered submissions (November 2025)'
    task send_november_2025_recovery_emails: :environment do
      dry_run = ENV['DRY_RUN'] == 'true'
      upload_to_s3 = ENV.fetch('UPLOAD_TO_S3', 'true') == 'true'

      # Hardcoded list of lighthouse upload IDs that need correction evidence emails sent out
      # (only those we've previously sent out failure notification emails to)
      lighthouse_upload_ids = %w[
        a29fbac2-6c54-4043-8767-bb84df914e33
        df70f6ce-ff74-4178-8457-42053dcc9840
        6edf7e27-0001-4ed1-bc9c-76d0969f2ada
        0bf6184f-0118-419b-a26b-0c1f7c2841c8
        f05d6fdf-1a29-4489-9721-3dc23c3a56af
        22d0ea5d-fe4d-4041-a5c6-87c867df7af0
        33fc299e-e072-4084-a623-f2cc5636befc
        8cc19bc7-3ecd-4bc3-8d7f-8a6809d79942
        4eaa30e1-2555-4431-b267-5c869c1cd210
        76eaf5b9-53b1-45bf-ba8b-b5c98fc7b22d
        eecc88ba-cec1-4df4-99f2-2b422eca6719
        e7eb8517-4816-49fb-afec-62195c02c7f0
        410a1c59-fdba-47bb-9265-8d44bf8ac36d
        12f14a48-e617-4f84-851c-a71b6b05ed58
        1931739c-ab71-4f4b-8d51-5b72c668f9c1
        2fff768e-d576-4531-b3ca-c9b85ce2057b
        e9c5826f-4dba-4fdd-8e1e-f781a5198b20
        2942de40-9a90-41d6-a088-da84d33581b2
        f4770ae6-f4af-4da0-a555-ec9707b04969
        4d69992f-b534-4125-9345-3eba4c6d012d
        2ebee1ce-a488-476a-950a-59d2b2b5969b
        bb94c80e-dbb8-4a76-94e6-46f3bb5f36eb
        a32b4771-c78d-4fff-b73d-41c12d51ca23
        1d8bb436-c490-4783-ad21-7a9afd6803c7
        d2702166-1274-41bf-858c-ee6dea8a527d
        acd2f702-b36d-4208-b3c2-65eeffb1d3f8
        db84604e-079e-4a19-9ec5-ca45a40b6042
        bd634edc-dde2-40b6-8a5d-cbd80aca598e
        f7e89f05-98f1-4f6a-a772-c44894d7b1a6
        253ac638-3619-47d8-8c73-d7cf80d94ecf
        c75d0def-6ddb-4378-9a80-c180ce19adc1
        fec0cdc0-bdfa-48f3-bd15-154f17828dfb
        17d7eb10-a7bc-42d4-8b58-b28dc4ec52ac
        00100085-bbd7-4358-95ae-18fdb0adec8b
        ce04fc84-898d-4f62-8b4b-d90f7ff5b2e7
        7f192b97-661a-4730-8d39-b9f3d1f24a64
        0982a2d4-ce35-4f26-b7e6-a7d018fc462a
        2a9898e7-6e32-48a3-b241-d38098c99d5a
        1ca47b96-12cd-4087-8d9f-7f437cdfd9de
        fe3298cc-f5d3-4a6e-864b-7e27aaed25d5
        cc5ff4f2-3a23-4445-a620-daf66e007bc9
        964095ca-5719-4ae0-86e3-368ef5bb88f6
        9bc52b5d-eb94-4ea5-8d42-7c3bea56187e
        c140ec86-87ba-4d3e-9792-1a46f691b63a
        c9083858-dbba-4576-8ddc-de09365db3aa
        832af903-290b-46ef-830c-65808cb7d8b2
        855948bf-0c9f-485e-ad36-a626461a2107
        cab728c5-648a-472f-a812-a666e734595c
        8b174564-5dbf-4cac-aab6-e17cbe183ddc
        b569a88e-2674-4345-8e68-43ff72ddc3e6
        5e16a8d7-75e7-4a91-9bad-e95c344ee5d8
        c49d50e2-ce64-4f1f-a6b2-ccfda3d55eec
        4490a9d0-165e-456f-a6df-634edec18c18
        83c1f391-1afc-426f-8d88-fd47de6dd148
        d8c475c7-69db-40a4-a07f-8fc7dc685d71
        81317e09-6962-4b68-a248-afdcb8118e73
        9c5652e7-6cc0-4a5a-b83b-639e9e750542
        3d051836-fd57-43b1-a66c-08ce5df8b082
        5875acac-7908-42f9-a979-c515658bc3a0
        2661d705-f4e3-4cff-81ff-1ff79937691a
        7db2659f-92e2-4182-8bdd-b0d49c63dcdb
        2ce8bf3a-d82c-4c58-be3e-7821eceaf006
        9b342f6d-7f28-4142-894b-a9c9c5064cda
        85a0826c-9beb-4ec7-b9d5-5a0a7be2bb36
        aee9a5cd-c7dc-4d48-ad3d-ce1148d484f6
        059551e1-bcc4-404c-b1ca-f56bed479b0f
        7b03150c-885a-44e3-a10e-00944d576271
        cb4bcbaa-fb5e-44a2-82cd-01851ce98315
        4b3ff3a8-964f-4c11-b688-46ae5f3a0e60
        33054ef6-0243-4178-9a6b-bf0f38d8369d
        d0a2863f-14f6-4762-9b3f-35845bb8d4e5
        2b3c1faf-ff27-4ab9-b87f-01ce74f535e5
        0fdecdbd-575f-4e85-b104-9a8253da811e
        854805fb-68df-412d-bd32-e0334f05340e
        ddd37618-33d1-475d-91c5-82b2d5e6212d
        98b384fe-4caf-4135-8ee8-933b84c3aa48
        e832345d-26fb-4e32-9527-4e78bda7b8fe
        ea4b9a8a-b8bb-47aa-8183-2efaf7eb92a1
        10f2d184-c6c6-4d6f-840a-65a646cad06d
        fd801dfe-c9fb-4e6b-87fa-be3fd4866145
        6fa93ca3-ea82-4fe7-aeaf-34e9017b5289
        227cdae3-9171-44b1-9499-8f53ee434aa9
        b87acb07-3cbe-4aaa-ae88-bc026e17d514
        f399640c-66d6-4b4c-8d41-a5622f695954
        78607d2b-2005-4ac6-9a49-1268aeaae556
        9414bdce-e4a2-42de-98ad-77916e0d4950
        4e4a70c7-09c5-46ba-b6dc-8325df09f9bf
        3729e2e6-004f-4edd-8c28-11a3ea93af9f
        a9927362-1f93-463f-bf69-2cb450dbc063
        045d38de-d106-49f9-818f-eb7d452271ec
        7bafbd33-084d-486b-9d20-b0559babbc89
        e227cf9c-65a0-474e-ba54-756f852a75be
        d08b5cd0-ca71-459f-82b3-01ab9a5c4287
        cb95e186-4d8b-4ffa-bfe9-1fd8075d52dd
        70d48af3-a087-42cf-b044-0456a45a6b09
        f331d233-68a9-4e9c-a9f1-0ecc2eb6d1ea
        f1c69ab0-0486-42f5-a086-2762eb8fb623
        a002a98f-c4a3-4703-a2b1-deb4c0a56c6e
        a4358865-10ed-4c17-9f80-843b1b0b207c
        7a547657-c1b8-4ba9-bf82-c57501bea357
        55d3534a-6245-4cff-bdb8-78d5867c8897
        00283909-0632-40c1-9b0a-385a9e3f454d
        a0322c99-ff99-4af4-a34d-e6b840aa45da
        ddc963b5-232c-4c8b-886c-5a96737998d4
        03f47240-1926-4d0a-be29-89043302e5a8
        2c5daf14-5b39-4991-9613-ad696685677c
        2fa066e4-8047-4d34-8475-acef16792532
        65635419-e19c-4e89-8056-597d0b1274f4
        dd496360-f432-40d7-bec6-569a2fb801dc
        e57047a5-6822-4ec0-8027-85c252c2978f
        e8c9b978-bc68-46fa-8ef2-f79d6a20b527
        a75a3ca4-fff7-49cb-91d7-25675cd2fce8
        57ab5d2e-8681-477e-bf5e-8f52886eda96
        a75935cc-8dbb-4ff8-8202-e6e85f55cce8
        56f6f36c-54b8-4887-918b-14de872e6a98
        464e38d6-34f6-4ff2-b953-3c7d26725558
        4d87cf48-bafc-47fa-8f8b-e14874fd7de6
        7471fac3-549d-4b2c-b99b-b80a6897605d
        ce93f551-b52f-4c96-9e14-864fe0cd3e4a
        c4e15b63-9f3a-4a2f-bd24-dc6ecf405c5f
        7a98da46-c066-40d5-a356-1d56bec72993
        685b52c5-8349-444b-81e2-f30aab549172
        1c17c047-2c62-469d-b17d-21c4d0d41061
        360f7468-d243-49c4-9337-781ffdc018cd
        91593cfb-b82d-471b-b7ed-85182cd1248c
        1fa93f3d-0753-4375-8363-2fa6d6fe403e
        7f11f094-374d-4e6d-8c87-868678965b1c
        40865228-eacd-4927-b526-4e558f153e85
        46fcae11-59b7-4d60-b0fa-52e14af61337
        16330175-2df2-47b5-bbd6-a4b91c66a848
        87cfbe2e-a09e-450a-b009-d9183be74c2b
        4dedeffc-ff6d-49e8-bd7e-e0360baca21d
        9a73a4d9-328c-4375-b1bf-914529f07a6b
        068cd836-5a24-426d-aed9-5ea2908298e0
        5e49e92c-4c51-41ab-ab18-72faad8ddf27
        96202c83-6837-4a5b-868f-40ba0ea877b0
        8bed7392-912a-4685-8072-0356b85a3c15
        5a4847fa-fc77-4f18-bcae-bfcfd5c00333
        c9285afa-bc69-43fb-a029-71078803c39c
        982402bf-cb84-4ed6-b9f0-9d344a4a8666
        0c2aed28-349c-4827-9b21-219302b4d3f2
        d61e60ed-d3d9-4aa2-a66a-1d11bd3c2d5f
        31dfdb02-78da-4b4a-bd27-ce3090f8caea
        4a29d520-6492-4766-b038-3aca353429ae
        fb3ecac1-9732-460d-91dc-32f1ca65cf06
        cf60f010-c7dc-452a-bc81-26392db7a488
        d5d0c0b1-ca95-497b-8a81-6a228b97bed3
        39b33b3d-beb5-4861-95a2-71f98cbc906f
        60b146b2-859b-467f-abe4-34c0858e2977
        89465a8d-85e2-4ee0-b6cd-b3d35ff6f8e9
        e809cffa-32e1-43d5-8af9-5fad3eb9fc04
        215547c5-9820-4c24-bbca-b790d56d9a7b
        3080bf51-ef12-43e0-920c-5a87d92e9855
        31c5ca22-61c0-4f54-bf87-8903e70f93f7
        bfe96f85-52a2-49a6-80ec-e2ca5aa1be36
        73fc7d35-50e0-424f-a5d2-86ac9c6c9cde
        20a2d01d-1b75-48cc-bd13-a77272b88c70
        7a3954fa-0b10-47e0-bd53-9ed806520269
        673f417d-3ca8-42c5-b47c-b3d7c98ff229
        492d6b4c-5f62-4878-b296-a702706f2d7e
        31481750-1dff-4fdb-b1cc-8c618dbf7079
        8ce22ad5-769f-4c03-a8f5-fcf3571ba82d
        d9472e85-341b-4dce-9cca-737c15b4ddeb
        cc38bc5f-a47d-4b9b-a186-fca7eca4e1e2
        74cd28a9-8693-495e-b4e2-de7138edd2d8
        78a49eaf-0b68-41b5-af79-d3220c37cc3b
        f929dbfe-df34-47c3-861e-e418fb3a75c3
        c1cbbf23-13a0-48f6-820c-b29bef8a06b9
        24a0fa9f-041d-4d4f-97f5-163643b8bc15
        23619646-dedf-48aa-9bdd-b3f349bfd446
        9c7a434c-0c0a-43d4-8002-de1bb14de847
        abf228b2-f23b-405e-bce3-98d0b11b4247
        fc8f1e01-2406-43ee-a39b-4841b8c2abab
        578047b4-76eb-40cd-995c-c3c3c0a61764
        4aaea75b-2d2b-4289-9df6-bbd63d5d9cc0
        c4402836-04f7-4335-bd50-66a39e617055
        6125f6b6-dcfa-4d34-97ec-cc9c5986fefd
        d2b69121-1a72-47bc-8b9b-e945f16eef0b
        5c8f942c-12d4-451c-bdcc-9d81b3a07f3c
        caf0ab94-3def-4ef0-be15-8a95b5aeb1c1
        d4a94cea-ecd1-4b4b-83ac-d7b68c48cac6
        d043f648-ac84-4902-8fde-5ed1e8069b7c
        0171475b-77bc-40a7-b00a-2cc7d24aeab7
        ece435df-bd24-4616-bdbc-1431bc1207ff
        c8d65641-f136-4ae0-85c5-68f885477f02
        30ae5ce2-6626-4908-b476-9988954495dd
        ba03f27b-4707-4795-883e-8bd49ccf2a66
        8c72bf35-00a3-4513-922c-0c862fac9679
        bc860195-2f15-44f2-b24c-743e300b0df7
        ea32c8e6-6046-4675-b997-75d8d92edee1
        35a2e82e-a6cc-455a-aaf9-534aacde44aa
        195ad110-060a-4caf-b0d4-287981ee8c4b
        83dcc83f-3029-4dde-9f99-5e9517b3a7b7
        a7f71997-aa53-4860-a865-5019d6eaa6ab
        55b610f2-1451-423f-a98c-e8728da52908
        0f07692a-81c3-4559-802f-fa0dda9293b0
        aa5101d5-77d0-4f43-9929-b5c330b6b716
        e0279a0b-f7cf-4d9c-be9f-c831f748fdc2
        9c85833a-8db5-4b3d-b198-49ce28b6401b
        3fa30331-808f-4421-b51e-afec88d7d51f
        00156a7f-b69e-4ccc-b549-728af8e3a2a3
        6836bbaf-5c43-44bd-b397-0d9d4195522d
        ce60d2bb-a667-4709-b66b-f6ffbfef4a84
        5ead4556-b2b8-4a15-9d00-5a2cd8990900
        07d15bf9-816f-42cf-b9bb-b7f3a4e2f4e6
        ba9eae88-9131-499f-be9a-275250467afe
        c2c41c31-3dbd-4ff1-b6a9-963e567316dd
        4d514a82-baa9-40f4-8661-a93617379944
        3d3440f9-847a-4dce-a3a8-4f77f9813f74
        b7b46349-1635-4d6a-a4f6-719d9c1e903c
        7d169cc8-b6c1-41e7-a3fb-ad788371ab91
        26f2614a-3f51-423c-a4ee-5b9e12e37dd8
        f298f217-5926-4dd2-9c09-5b669c3a116f
        688c0bb3-a9ba-4dff-b3c5-ee63d1c46691
        a4289af0-86e9-4881-8c2a-3f0d46c43379
        20922452-11c6-42e3-ab94-567b006490ef
        6b547f5e-00e9-486e-b0c0-d10118a26df7
        f1933ea0-d67a-408d-9ef2-e243881000a6
        2d8af34a-c945-4e9a-bdda-d00251b3a3b7
        eebf06de-2404-453a-b1bd-a5698e4ba25f
        bc24e0e8-21bb-44c1-a7ad-1393cc9fa552
        3932f097-55f1-40fb-9d8e-858af6bee507
        6fda76e5-4aee-4250-9320-ea20e1a45a1a
        ab6cfcb7-9f19-4e93-a422-978756115951
        0189c8cb-76c1-4449-b28a-d8ba7f7ee2c1
        0b97582c-365a-419c-8cce-028f3213577b
        c1edfbb4-d8e7-45b7-b13d-5ef519bd2ddc
        b6d5315e-2b5a-4911-94f7-9a2a351d444e
        ba724383-1c57-4d03-ae97-9a237c0d2fdd
        7429916f-7f4b-4f49-86c5-4fe0ee97b666
        e685f8eb-e252-41bb-8462-bdc1576e2a8e
        31b0ebd7-9d44-428c-9900-a0c8f37b4d5e
        984310d9-058a-49bf-8fdd-6c8f65383266
        19af3d40-71b8-4f90-ab8b-13a7e47f639e
        ca3bfd6e-c268-4ffd-b258-33c836e8f043
        2711f1dc-1339-480a-8931-e3975a3684cb
        eb150d56-ab17-4d4e-8394-0480e21e5688
        a7701c39-40ba-47e1-b042-e22680149cf6
        8b9979e3-8008-4587-bddd-ba0d82457bf9
        adc83a90-9418-4fc8-9d7b-c91c87c3749f
        8941b8c5-3120-47c8-84e9-599a533c601f
        051df8a0-7d63-4229-8da8-2e75d4090e74
        c93fce30-bfcf-4517-ad67-d462913d393c
        9fe6f1b5-6fa3-4733-a9a2-4c40d2bb7ba1
        7bc27d7c-df16-4461-a534-ca8bc08349ac
        3bad79c2-dcd5-4668-ae35-81b5a15bee42
        fe350077-3fd9-49a0-9947-b38fb192ddc4
        e04ae3b8-cf45-42b4-942a-17866c0d4a58
        63ef1673-615f-4557-8e0d-6fd05f2d1fd7
        6841f882-91bb-40c6-8265-39f0130914e3
        99e0c690-7a42-4497-88d6-f442d174e6ed
        3c36ee42-6ffa-47a6-a720-45db7c1c94d5
        669bd626-37ba-4ae6-aed8-051775e38676
        bda26468-5420-4f29-b506-3c7e8a368223
        17abd23f-8393-4044-b675-efc6acd19b4d
        2525bca7-81de-475a-8e88-35cf412258d4
        1699d004-5418-4ab2-a2dd-5c23c643b883
        cebaaf40-7df6-4521-83ac-170b52cae049
        fc9e90ae-f0b6-4cf6-9619-fd7ea2434269
        a8fd923f-4c40-4558-a770-fcff065725fa
        43ae2473-aa46-48f6-add7-b963488d4216
        07e2956f-5703-43f3-a2d9-0779536ffb7e
        cd3b7f12-d97a-42e3-a0a9-59eef58453d8
        0458ed82-93f1-45de-b747-2590cee76ea9
        90b9f710-6a24-4535-ae71-79aa49a4a7e2
        79106c75-6e75-4116-946c-1e651d57c2a0
        8196c200-a35c-473d-adf0-c772f607092e
        57d0b0c4-844e-4eaa-ae37-ade0b97a1828
        a6b3b267-a049-414b-9e8a-87a4ff1d7f6c
        69f70bb2-c07a-4b20-b25f-605d89d23f8e
        bf45c535-4517-4b42-8138-9d6965115607
        c0720c7d-ce28-4cec-a215-9417c70ab3d2
        82d69102-3b15-45cc-9567-958f940970e3
        81c468c2-6829-4f82-9a35-add31141c7f8
        8e65cb34-d4a6-4d7c-9712-214ceee7f226
        36b2e2aa-bb8f-4abd-8f26-391dd1db2935
        85f3c11a-7a04-47d7-89bd-fcc917995546
        3b356213-e54e-41af-9ef0-3369219cae8e
        1faada60-e3e1-4045-9229-c62c01f4854d
        7172f922-ceb2-4822-9567-8ed519dbbb1f
        c6b9ffac-abd7-4fcf-9a4a-4239695ceed0
        53567a84-4675-4aad-9297-ec6cc81b7441
        2365c720-aef4-460a-b111-87e4e0feaa15
        7bbb8097-db77-49c9-9ab1-d11c6870f345
        1fcd0eeb-78b2-40b5-8354-bad7843bd6b8
        0764a15b-4529-4b0a-b976-da6da28ddeba
        ba6bb392-1548-40e8-a1b2-690b4f2ac95b
        a859d1f0-b854-4165-8d0f-6d3ea35027bc
        f3836972-a633-4b5e-be59-1a2cb4a269c5
        6cae8ede-7348-40be-98a9-3ab3c3425695
        52aa98a4-87db-4c88-8b27-8f724f8465c1
        e6b2d598-c835-48ba-98c2-4fc90c40350d
        9a75f6cd-b61f-49b3-9682-bb976c5bdef5
        bce4a209-870f-4f3a-ab2e-62295e09d7ae
        ea3bb41b-a1a1-4739-9caf-74f1d54d43cf
        4d02e73d-d2a6-42b7-a361-5d3d688df1ee
        838088f0-545b-4871-9a90-5c15fbd81aae
        6c6ab538-d280-41bf-9779-603f0d446774
        40e6b49f-eff8-44d4-a272-19cd1ac6723e
        eefaa81e-c381-4cd0-a325-8b158a273ea1
        e678f180-c679-44bd-b7b2-c81ebf46a46a
        5b544a6d-8f88-4e26-be8f-6bda40a3dfc0
        dbe195cd-4474-4ef3-9039-b57190526fca
        f9faafae-e122-4c37-a811-82e59be1d4e7
        99079c19-19ed-4006-b669-ac6bead87de8
        74147a22-e8e7-4402-b928-d59fb28744fa
        59ef89fa-5c10-45fe-9ac8-bb1d06560b4d
        d2297020-db10-4e57-8206-3b46e511f024
        67d1babd-81fd-46ca-b089-9774d5fa3c06
        c968fc19-e799-4dec-a683-8ddecfd9059f
        14ab3078-c786-4d43-a45d-4482c51d65a1
        fd7b1731-bd24-47a1-93db-b9bc3922e15d
        f51c0987-7f08-4afa-86d0-dca1d407909a
        6f3ce74a-64b3-4b46-91ac-44a57f9b8ad1
        6226bfb4-cfd9-4778-b286-71bb2a7d5ecd
        ea66a6f2-92cc-4a5f-bf5a-1be5daf48bae
        f0443baa-6b69-45eb-8894-fd282d6e799d
        b1412eb8-be2d-4676-804b-872f267ec659
        3f1f6357-9dce-4b2c-af58-e16ff7294bf8
        3229284c-5260-4d0e-ae73-172583c6c28e
        efd857d0-5c53-468f-8d14-1cac10decb7a
        afad6e10-9f23-490e-9935-1fef4c5ef817
        0a3ec44f-7f3f-4752-bed9-97ef9756e3a8
        4276965d-0f03-42d0-a39b-7d036299d280
        0bcf7ef1-6bf6-4e89-abc7-9a5bcface79b
        3765b29c-f198-4053-8cc6-6eb188286d83
        c309c291-9d3b-4fa6-a6d7-26d08fe3c480
        0e81fe77-5244-4197-8d96-850f50043e47
        9725139e-cd05-4d10-bd13-8bd589d3c537
        52220228-bae7-4b78-b5db-205c3fe25979
        624a0905-838b-43d4-b5eb-e0a79d05b787
        24d0823c-29c6-4c49-8448-153255a5662d
        ac99febe-7127-4dfc-aaec-fe2e5589360a
        7667b82e-07f6-4456-8f14-50fa36868da1
        b8831303-95c5-43aa-bba2-7f3ea6fe5eba
        e1635131-1390-4665-89d7-3c4b5e384072
        f0d33a94-59f5-401b-b8cb-425e72795944
        d2b6e4d2-b9dc-4cca-bd66-76a951a50084
        f8296da1-c118-4a36-a994-b6de8a3e4f5f
        2ca2d902-35a2-4c48-bb95-11fb6739ff57
        9765d501-86e4-49b0-9a42-703b493f9215
        fae7513a-68e4-40c2-a7d6-07b3ca7a77f9
        e85ad13d-c3b9-43a7-9188-42b2ee77b130
        3c81a146-2b06-4441-a2af-94ecb8153ea2
        3651a991-7dda-468c-b4d6-78940a171472
        db2a3b17-50cd-45fb-b2e6-209fc04cb421
        25c1ee35-7370-4c35-8ba7-3dffbe90b2b1
        cc8bfdea-27f1-4119-ae24-ed06afae7c02
        6fcb5c99-266b-4de7-9c24-07b23c7f120c
        a08bbf67-b443-4ed3-aee6-e28982bcc716
        0daa4e46-f895-422e-8f41-03522b3bd377
        2771393d-7451-44fe-ac87-093b8eb84b9f
        2b216e44-f2f5-4ea8-8dba-3cb46a90f8b3
        64cbcef5-e5dc-4690-94bc-81ea6b1db66a
        2dd9b90e-c48b-44d7-a191-a4c781afe42a
        fee9ac65-c250-41b6-b9bc-49e6da79f44c
        c96f622b-0d25-488b-afb2-877a1e26c650
        adf832bf-73d9-471f-a1d8-82ecf061679e
        7c46a0cf-2c1c-4909-b91a-30faec2507ee
        748b9826-bc78-470c-9687-5c72be99f249
        15e0579b-d282-4c0e-a161-cc7374b4fd9c
        4c6ca965-314a-4bb8-8ee6-659e5b644dfc
        35519bd7-cea2-4bd9-9057-9c9b7d8b81b7
        bb4e8335-130b-48eb-9faa-592b1290552b
        9e588d97-55d4-4f02-bea0-5689df08220b
        a9a0e32d-70e7-4f5e-895a-25c5236cfb92
        adaba3fe-d035-404e-80e3-255b30544d36
        ad121e94-e8ce-4af0-ba91-7e00cc0ed0ed
        a021ca28-f379-4a46-97e6-403ab015132c
        29bd6fd9-14cb-447b-927f-618a722536c8
        8b961569-5c52-4f23-96f5-98c360d6cbe6
        08d8be63-f292-4622-9386-15c3e7e978e7
        63504a50-4465-422f-bae4-cfb53e9e892f
        9a6616da-cb6a-41de-97d2-bde96c84551e
        a4812582-4c74-49ea-aa4c-ee6651cb61ba
        9a608d31-0592-4202-948f-25084d122174
        f903ae2e-9e23-43bf-b2ad-4f97ddcc02b5
        784c13d6-1156-472f-9e55-a534eac4f0d0
        da69c646-9683-4e77-bcea-02a7738215cb
        40d08425-d4ba-4921-8cd0-ca39c5a28840
        5e452364-2362-49f4-b220-7298370175ac
        b32b8dd8-eab2-43e4-92db-9d25475524a2
        257fdb72-4a63-41ea-a27e-df2ec57ac834
        b31125b9-ec2e-444e-b0ed-7cd8d950acf6
        9d9073cc-2abb-411a-a5a0-60413fa1a210
        2e63dea0-6979-41d5-90e6-fb65df9949ce
        397e9604-c2f7-4668-9f6a-f9bd52a2919d
        3c7c3041-bd5a-40aa-9ebc-018d3ed6a400
        857a8a92-0d1b-4b34-b921-10dbf12e07da
        54656991-159c-4e60-97ca-d95634ea54ce
        59cb75ec-e543-497d-9ccf-e84b3ddfed24
        812e129d-d281-4eb6-b43f-33fc43ee3766
        429715da-4c5c-4c28-bcd8-40f79900ac5c
        05495054-16ee-4a07-898b-c6c1f7d5d0d0
        7ac7c91c-cc60-438c-aa63-98a7f874df28
        8b5ef3c7-4f68-487c-98ab-2331fff41182
        b86a26d2-4a49-4faa-9f3b-51511c3b12ca
        d0f58937-b8cb-4482-aa57-1ebc6f33a347
        f9494786-da67-4f6a-94ca-26d29b734f5d
        75cad579-63f8-4e02-a01c-fb744f51761b
        081c9b50-4df6-47a6-acea-ec5274155c78
        d325bbae-e038-4105-8515-09884e786c0b
        8f8edee0-32e8-4a1f-a0b0-5b283d92e069
        2288a458-a431-4219-a509-5c0d23ec80ca
        918170ad-cf2e-4b2a-88e2-97621fa54a28
        abd1db34-4001-418c-95b8-7064ad403dbc
        78b0c1c1-6956-4a3e-9dfe-068078b2314d
        d2aab71c-725f-47db-b6a1-65f100b5af26
        c65e7ca4-6072-489b-9838-76e8f0f9a550
        3dfb88d8-391d-4b61-8481-c59f192f954d
        c32c89f0-7c6b-446f-988e-324b8a2b2456
        74141146-3fb7-4709-bb00-a8283886e0fd
        38923ce2-4e1c-463f-bddb-3bef9c1cd69f
        7c42b00d-a0b6-46f5-a1fc-9efeda7e3e5d
        db3facf7-e36f-4927-88f7-a897b67e6ea8
        8312e152-3a33-4e24-a2d8-acf3fb3fa6ea
        e281fcda-6b31-4848-9735-7a1dd08f79d3
        a0a3f28c-2b0d-47f2-a94f-18740b6b69bc
        ba4216d0-973b-431d-a074-586a97f48774
        1f6865e2-0793-4446-8542-eaf307a6a933
        670de3c0-ec57-4b89-b398-e1bcd57be071
        0a66b139-a49d-4f27-8ea3-1da4cb4aeb07
        d56014e7-7ebb-4f9a-934d-269db82aebc3
        221c2568-361f-4855-bb04-94634fdb336f
        72cb2f5b-808e-4ea3-863b-4474ba12a8a7
        0a8e7521-2f6b-4611-940e-2e5a17804bc4
        759ee1f1-248f-43e3-a3b2-90c9e7323bc9
        b7258755-496a-4a1b-9910-766d2728a76d
        60f26b32-08f4-4f44-b91b-f772a2e52296
        eb1c407d-f1ec-425d-b1ae-8655f8a9f2d1
        5ef2f2ca-d086-46be-950a-72dee2f6f6f3
        4140c72a-8bd3-4571-aed4-4388b4bf5542
        0384b53d-20ab-4a05-a15e-6e738db7182f
        13c9dabb-a7ec-4a64-8f85-e03c1d221087
        debf806f-1b4a-41ad-9908-a6d4ca168dc0
        819b0ee4-974a-4dda-827d-6dc76b4714e7
        e12de5ac-ee2c-4dea-b8d2-d39c0ce90685
        a1a6b0e5-d835-48de-a982-70de8c598a15
        50037304-49bb-4ab7-88c8-038cc0913c4b
        03ca2663-fe6b-4a62-b424-9e9029cb4a47
        6541fb39-c173-4834-8c77-87d4e0001538
        495ee68e-439c-4297-b7a2-0acbf6634098
        44dfbc0b-8c21-4039-9ee4-777d52d8dde6
        35124598-83bf-4778-800f-30cd499db24e
        241bc6fc-5e7d-40bf-af7c-9e175e675beb
        47ff65d6-6103-4036-abb4-1b9bd98b9d88
        9ab92fd0-01ff-467b-b855-8a8fda71b56f
        4ddb3dcd-1c9a-42d2-8fd6-aee0043b6c2b
        c41c6e0a-d070-421a-9dd3-70c9bee34fb8
        92391cc7-cbf6-4b15-94ab-37f3e38c457c
        62d8d520-f3a2-4df0-8e57-265a8a00e708
        00ffcb4a-3d1b-493a-9701-1c9838cc81f3
        915bc8e3-9be3-41b0-b7f7-91a920790626
        ef8e956d-0983-4d97-a315-4a987bbe65ab
        034bfa35-38dc-46e1-832a-a1b19bc9469f
        d833ee72-efd0-4695-81e8-e3b9764cbd2f
        fbce009f-e438-4da8-a178-07a7f321e5d1
        79e51770-2ce5-486b-ba81-08bc6c45a7c6
        60906db9-63af-46e9-bb3d-c1b312eaa812
      ]

      # Hardcoded list of appeal submission IDs that need correction form emails sent out
      # (only those we've previously sent out failure notification emails to)
      appeal_submission_ids = [740595, 740600, 740603, 748840, 748845, 748848, 748850, 748861, 748863, 748870, 748874, 740605, 740611, 740612, 740613, 740614, 740618, 748836, 748839, 748875, 748877, 748880, 748882, 748885, 748889, 740615, 740590, 740596, 740597, 740598, 740601, 740602, 740608, 740609, 748835, 748837, 748844, 748846, 748838, 748843, 748881, 740607, 740591, 740610, 740592, 740616, 740606, 740593, 740594, 748857, 748856, 748858, 748859, 748860, 748862, 748865, 748868, 748871, 748872, 748873, 748878, 748879, 748883, 748884, 748886, 748887, 747735, 740599, 740604, 748842, 748888, 748876, 754401, 754403, 754478, 754460, 754441, 754429, 754430, 754418, 754459, 754470, 754468, 754475, 754487, 754471, 754490, 754405, 754350, 754362, 754419, 754367, 754509, 754446, 754423, 754329, 754585, 754500, 754512, 754576, 754577, 754588, 754480, 754543, 754462, 754546, 754453, 754560, 754599, 754604, 754609, 754610, 754665, 754632, 754650, 754655, 754657, 754661, 754601, 754574, 754622, 754578, 754600, 754317, 754301, 754312, 754318, 754335, 754383, 754351, 754358, 754370, 754377, 754379, 754368, 754390, 754296, 754307, 754331, 754333, 754399, 754467, 754476, 754477, 754485, 754541, 754553, 754617, 754627, 754663, 754671, 754692, 754742, 754746, 754283, 754310, 754455, 754287, 754319, 754309, 754303, 754352, 754353, 754355, 754363, 754365, 754369, 754488, 754416, 754384, 754289, 754295, 754425, 754426, 754428, 754440, 754450, 754538, 754498, 754503, 754504, 754505, 754506, 754507, 754779, 754516, 754556, 754562, 754564, 754573, 754575, 754579, 754586, 754580, 754581, 754583, 754584, 754587, 754589, 754594, 754635, 754638, 754639, 754662, 754660, 754675, 754648, 754652, 754669, 754653, 754654, 754658, 754664, 754668, 754670, 754672, 754690, 754693, 754698, 754729, 754763, 754704, 754706, 754709, 754710, 754711, 754712, 754743, 754721, 754723, 754725, 754726, 754727, 754731, 754734, 754738, 754740, 754749, 754751, 754685, 754680, 754695, 754754, 754760, 754767, 754768, 754770, 754771, 754772, 754774, 754775, 754780, 754773, 754759, 754386, 754313, 754316, 754320, 754354, 754323, 754325, 754332, 754338, 754340, 754452, 754394, 754395, 754396, 754400, 754414, 754443, 754456, 754458, 754465, 754466, 754469, 754496, 754479, 754481, 754483, 754484, 754527, 754424, 754421, 754417, 754412, 754520, 754521, 754526, 754536, 754542, 754544, 754547, 754550, 754551, 754598, 754603, 754605, 754607, 754464, 754472, 754566, 754611, 754612, 754614, 754636, 754621, 754625, 754626, 754673, 754634, 754684, 754613, 754645, 754686, 754715] # rubocop:disable Style/NumericLiterals, Layout/LineLength

      # Create output buffer to capture all output
      output_buffer = StringIO.new

      # Process evidence recovery emails
      evidence_result = process_evidence_recovery_emails(lighthouse_upload_ids, dry_run, output_buffer)

      # Process form recovery emails
      form_result = process_form_recovery_emails(appeal_submission_ids, dry_run, output_buffer)

      # Print summary
      puts "\n#{'📊 ' * 40}"
      puts 'EMAIL SENDING COMPLETE'
      puts '📊 ' * 40
      puts "\nEvidence Recovery Emails:"
      puts "  Processed: #{evidence_result[:stats][:processed]}"
      puts "  Sent: #{evidence_result[:stats][:sent]}"
      puts "  Skipped: #{evidence_result[:stats][:skipped]}"
      puts "  Errors: #{evidence_result[:stats][:errors]}"
      puts "\nForm Recovery Emails:"
      puts "  Processed: #{form_result[:stats][:processed]}"
      puts "  Sent: #{form_result[:stats][:sent]}"
      puts "  Skipped: #{form_result[:stats][:skipped]}"
      puts "  Errors: #{form_result[:stats][:errors]}"
      puts "\nFinished at: #{Time.current}"
      puts '=' * 80

      if dry_run
        puts "\n⚠️  DRY RUN MODE - No emails were sent"
        puts 'Run without DRY_RUN=true to send emails'
      end

      # Upload to S3 if enabled
      upload_email_results_to_s3(output_buffer.string, dry_run) if upload_to_s3
    end
  end
end
