# frozen_string_literal: true

require 'reports/uploader'

module SimpleFormsApi
  module S3
    class Utils
      private

      def assign_instance_variables(defaults)
        defaults.each do |key, value|
          instance_var = instance_variable_get("@#{key}")

          instance_variable_set("@#{key}", value) if value && instance_var.to_s.empty?
        end
      end

      def log_info(message, **details)
        Rails.logger.info(message, details)
      end

      def log_error(message, error, **details)
        Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
      end

      def handle_error(message, error, **)
        log_error(message, error, **)
        raise error
      end

      def temp_directory_path
        @temp_directory_path ||= Rails.root.join("tmp/#{benefits_intake_uuid}-#{SecureRandom.hex}/").to_s
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
