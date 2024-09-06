# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    class Utils
      private

      def log_info(message, **details)
        Rails.logger.info(message, details)
      end

      def log_error(message, error, **details)
        Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
      end

      def s3_resource
        @s3_resource ||= Reports::Uploader.new_s3_resource
      end

      def target_bucket
        @target_bucket ||= Reports::Uploader.s3_bucket
      end
    end
  end
end
