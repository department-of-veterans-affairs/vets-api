# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

module DecisionReview
  class NodEmailLoaderJob
    include Sidekiq::Job
    include DecisionReviewV1::Appeals::LoggingUtils

    sidekiq_options retry: false

    LOG_PARAMS = {
      key: :nod_email_loader_job,
      form_id: '10182',
      user_uuid: nil
    }.freeze

    def perform(file_name, template_id, s3_config = Settings.decision_review.s3)
      emails = get_emails(file_name, s3_config)

      line = 1
      emails.each_line do |email|
        DecisionReview::NodSendEmailJob.perform_async(email.strip, template_id, line)
        line += 1
      end

      log_formatted(**LOG_PARAMS, is_success: true)
    rescue => e
      log_formatted(**LOG_PARAMS, is_success: false, params: { exception_message: e.message })
    end

    private

    # returns StringIO
    def get_emails(file_name, s3_config)
      credentials = Aws::Credentials.new(s3_config.aws_access_key_id, s3_config.aws_secret_access_key)
      s3 = Aws::S3::Client.new(region: s3_config.region, credentials:)
      s3.get_object(bucket: s3_config.bucket, key: file_name).body
    rescue => e
      raise "Error fetching #{file_name}: #{e}"
    end
  end
end
