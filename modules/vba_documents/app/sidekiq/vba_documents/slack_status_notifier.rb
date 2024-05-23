# frozen_string_literal: true

require 'sidekiq'

# Triggers slack notification for Upload Submissions stuck in specific statuses if the counts exceed
# thresholds that could indicate an issue. Not really intended to track individual Upload Submissions,
# but instead is intended to find wide scale problems potentially impacting all consumers.

module VBADocuments
  class SlackStatusNotifier
    include Sidekiq::Job
    include ActionView::Helpers::DateHelper

    # Only retry for ~30 minutes since the job is run every hour
    sidekiq_options retry: 5, unique_for: 1.hour

    # Number of hours in the past to query for expired uploads, expired is a
    # terminitating status that never clears and we only want to report on recents
    EXPIRED_LOOKBACK_HOURS = 1

    # Expired threshold in percent to trigger notification
    EXPIRED_THRESHOLD = 3.0

    # Upload submisions in uploaded status for more than 100 minutes are considered stuck
    # Between UploadScanner and RunUnsuccessfulSubmissions, 100 should give us ~3 submission attempts
    # 15 minutes for consumer to push file
    # 2 minutes for UploadScanner to pickup s3 upload
    # 5 minutes run time for attempt #1
    # 35 minutes wait\run for upload processor sidekiq retry 1
    # 35 minutes wait\run for upload processor sidekiq retry 2
    UPLOADED_AGE_THRESHOLD_MINUTES = 100

    # Consumer's who could have their Submission'ss upload to EMMS\CM delayed
    DELAYED_EVIDENCE_CONSUMERS = %w[appeals_api_nod_evidence_submission appeals_api_sc_evidence_submission].freeze

    def perform
      return unless Settings.vba_documents.slack.enabled

      report_expired
      report_uploaded
    end

    def report_expired
      # A large number of expired uploads could indicate an s3 issue, for example in the past a misconfigured s3 key
      # allowed consumers to successfully request s3 upload urls and tracking GUIDs, but they not able to push their
      # files to s3 resulting in a large number of expired upload submissions
      created_at_range = EXPIRED_LOOKBACK_HOURS.hours.ago..DateTime.now
      new_count     = VBADocuments::UploadSubmission.where(created_at: created_at_range).count
      expired_count = VBADocuments::UploadSubmission.where(status: 'expired',
                                                           created_at: created_at_range).count
      percent_expired = (expired_count.to_f / new_count) * 100.0

      if percent_expired > EXPIRED_THRESHOLD
        message_time = created_at_range.first.in_time_zone('America/New_York')
                                       .strftime('%Y-%m-%d %I:%M:%S %p %Z')
        fail_rate = ActiveSupport::NumberHelper.number_to_percentage(percent_expired, precision: 1)
        message = "#{expired_count}(#{fail_rate}) " \
                  "out of #{new_count} Benefits Intake uploads created since #{message_time} " \
                  'have expired with no consumer uploads to S3' \
                  "\nThis could indicate an S3 issue impacting consumers."

        notify_slack(message, expired_details_rate_by_consumer(created_at_range))
      end
    rescue => e
      notify_slack("'Expired' status notifier exception: #{e.class}", e.message)
      raise e
    end

    def expired_details_rate_by_consumer(created_at_range)
      # break out expired rates by consumer
      consumer_all_counts = VBADocuments::UploadSubmission.where(created_at: created_at_range)
                                                          .group(:consumer_name).count
      consumer_exp_counts = VBADocuments::UploadSubmission.where(created_at: created_at_range, status: 'expired')
                                                          .group(:consumer_name).count

      # calc expired rate% by consumer
      exp_rate = consumer_all_counts.map { |name, count| [name, (consumer_exp_counts[name].to_f / count) * 100] }

      # sort by Consumer expired Rate, build slack reporting string
      slack_details = "\n\t(Consumer, Expired Rate)\n"
      exp_rate.sort_by { |e| -e[1] }.each do |cr|
        slack_details += "\t#{cr[0]}: #{ActiveSupport::NumberHelper.number_to_percentage(cr[1], precision: 1)}\n"
      end

      slack_details
    end

    def report_uploaded
      # Upload Submisions stuck in uploaded status indicate the consumers are able to push their
      # file to s3 but we are unable to process it.
      uss = VBADocuments::UploadSubmission.where(status: 'uploaded',
                                                 created_at: ..UPLOADED_AGE_THRESHOLD_MINUTES.minutes.ago)
                                          .order(:created_at)
      if Flipper.enabled?(:decision_review_delay_evidence)
        # if delay appeal evidence is on(max delay of 24 hours), look for any appeal's evidence
        # uploads that have exceeded the max delay of 24 hours plus the normal time we allow
        # the UploadScanner Sidekiq job to pickup the submission and upload to EMMS\CM
        max_age = (24.hours + UPLOADED_AGE_THRESHOLD_MINUTES.minutes).ago
        uss = uss.where.not(consumer_name: DELAYED_EVIDENCE_CONSUMERS)
        uss = uss.or(VBADocuments::UploadSubmission.where(consumer_name: DELAYED_EVIDENCE_CONSUMERS,
                                                          status: 'uploaded',
                                                          created_at: ..max_age))
      end

      if uss.size.positive?
        message = "#{uss.size} Benefits Intake Submissions have been in the uploaded status " \
                  'for longer than expected. This could indicate an issue with Benefits Intake or Central Mail'
        notify_slack(message, uploaded_details(uss))
      end
    rescue => e
      notify_slack("'Uploaded' status notifier exception: #{e.class}", e.message)
      raise e
    end

    def uploaded_details(upload_submissions)
      # sort by age in uploaded and kick out some details
      uss_sorted = upload_submissions.map do |us|
        upload_age = Time.zone.now - us.created_at
        [us.guid, upload_age, us.metadata['upload_timeout_error_count'], us.metadata['size'], us.detail]
      end

      # gather details and report
      slack_details = "Oldest 20 Stuck Upload Submissions\n"
      slack_details += "\n\t(Guid, Age(Hours:Minutes), upload retry count\n, upload size), detail\n"
      uss_sorted.first(50).each do |us|
        slack_details += "\t#{us[0]} " \
                         "#{us[1].to_i / 3600}:#{format('%02d', (us[1] / 60 % 60).to_i)} " \
                         "#{us[2] || 0} " \
                         "#{ActiveSupport::NumberHelper.number_to_delimited(us[3])} " \
                         "#{us[4]}\n"
      end
      slack_details
    end

    def notify_slack(message, results)
      slack_details = {
        class: self.class.name,
        alert: message,
        details: results
      }
      VBADocuments::Slack::Messenger.new(slack_details).notify!
    end
  end
end
