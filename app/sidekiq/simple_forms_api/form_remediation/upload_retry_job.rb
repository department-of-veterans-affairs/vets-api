# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class UploadRetryJob
      include Sidekiq::Job

      sidekiq_options retry: 10

      STATSD_KEY_PREFIX = 'api.simple_forms_api.upload_retry_job'

      sidekiq_retries_exhausted do |_msg, ex|
        StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
        Rails.logger.error(
          'SimpleFormsApi::FormRemediation::UploadRetryJob retries exhausted',
          { exception: "#{ex.class} - #{ex.message}", backtrace: ex.backtrace&.join("\n").to_s }
        )
      end

      def perform(file, directory, config)
        @file = file
        @directory = directory
        @config = config
        uploader = config.uploader_class.new(directory:, config:)

        begin
          StatsD.increment("#{STATSD_KEY_PREFIX}.total")

          uploader.store!(file)
        rescue Aws::S3::Errors::ServiceError
          raise if service_available?(config.s3_settings.region)

          retry_later
        end
      end

      private

      attr_accessor :file, :directory, :config

      def service_available?(region)
        Aws::S3::Client.new(region:).list_buckets
        true
      rescue Aws::S3::Errors::ServiceError
        false
      end

      def retry_later(delay: 30.minutes.from_now)
        Rails.logger.info("S3 service unavailable. Retrying upload later for #{file.filename}.")
        self.class.perform_in(delay, file, directory, config)
      end
    end
  end
end
