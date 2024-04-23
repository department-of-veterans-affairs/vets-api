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

    def perform(file_name, template_id, s3_config)
      csv_file = get_csv(file_name, s3_config)

      line_num = 1

      csv_file.gets # skip CSV header
      csv_file.each_line do |line|
        email, full_name = line.split(',')
        DecisionReview::NodSendEmailJob.perform_async(email, template_id, { 'full_name' => full_name.strip }, line_num)
        line_num += 1
      end

      log_formatted(**LOG_PARAMS, is_success: true)
    rescue => e
      log_formatted(**LOG_PARAMS, is_success: false, params: { exception_message: e.message })
    end

    private

    # returns StringIO
    def get_csv(file_name, s3_config)
      credentials = Aws::Credentials.new(s3_config[:aws_access_key_id], s3_config[:aws_secret_access_key])
      s3 = Aws::S3::Client.new(region: s3_config[:region], credentials:)
      s3.get_object(bucket: s3_config[:bucket], key: file_name).body
    rescue => e
      raise "Error fetching #{file_name}: #{e}"
    end
  end
end
