# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class SlackExpiredNotifier
    include Sidekiq::Job
    include ActionView::Helpers::DateHelper

    # Only retry for ~30 minutes since the job is run every hour
    sidekiq_options retry: 5, unique_for: 1.hour

    # Number of hours in the past to query for expired uploads
    LOOKBACK_HOURS = 1

    # Expired threshold in percent to trigger notification
    EXPIRED_THRESHOLD = 3.0

    # A large number of expired uploads could indicate an s3 issue, for example in the past a misconfigured s3 key
    # allowed consumers to successfully request s3 upload urls and tracking GUIDs, but they not able to push their
    # files to s3 resulting in a large number of expired upload submissions
    def perform
      return unless Settings.vba_documents.slack.enabled

      created_at_range = LOOKBACK_HOURS.hours.ago..DateTime.now
      new_count     = VBADocuments::UploadSubmission.where(created_at: created_at_range).count
      expired_count = VBADocuments::UploadSubmission.where(status: 'expired',
                                                           created_at: created_at_range).count
      percent_expired = (expired_count.to_f / new_count) * 100.0

      if percent_expired > EXPIRED_THRESHOLD
        message_time = created_at_range.first.change(zone: 'Eastern Time (US & Canada)')
                                       .strftime('%Y-%m-%d %I:%M:%S %p %Z')
        fail_rate = ActiveSupport::NumberHelper.number_to_percentage(percent_expired, precision: 1)
        message = "#{expired_count}(#{fail_rate}) " \
                  "out of #{new_count} Benefits Intake uploads created since #{message_time} " \
                  'have expired with no consumer uploads to S3' \
                  "\nThis could indicate an S3 issue impacting consumers."

        notify_slack(message, consumer_details(created_at_range))
      end
    end

    def consumer_details(created_at_range)
      # break out expired rates by consumer
      consumer_all_counts = VBADocuments::UploadSubmission.where(created_at: created_at_range)
                                                          .group(:consumer_name).count
      consumer_exp_counts = VBADocuments::UploadSubmission.where(status: 'expired', created_at: created_at_range)
                                                          .group(:consumer_name).count

      # calc expired rate% by consumer
      exp_rate = consumer_all_counts.map { |name, count| [name, (consumer_exp_counts[name].to_f / count) * 100] }

      # sort by Consumer expired Rate, build slack reporting string
      slack_details = "\n\t(Consumer, Expired Rate)\n"
      exp_rate.sort_by { |e| -e[1] }.each do |cr|
        slack_details << "\t#{cr[0]}: #{ActiveSupport::NumberHelper.number_to_percentage(cr[1], precision: 1)}\n"
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
