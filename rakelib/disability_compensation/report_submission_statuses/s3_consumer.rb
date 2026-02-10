# frozen_string_literal: true

module DisabilityCompensation
  class ReportSubmissionStatuses
    class S3Consumer
      def initialize(filter, now)
        @filter = filter
        @now = now
      end

      def perform(each_submission)
        Tempfile.create do |file|
          write_file(file, each_submission)
          get_link(file.path)
        end
      end

      private

      EXPIRY_DURATION = 1.week

      def get_link(file_path)
        settings = Settings.form526_export.aws
        resource = settings.to_h.slice(*%i[region access_key_id secret_access_key])
        resource = Aws::S3::Resource.new(resource)

        object =
          Common::S3Helpers.upload_file(
            s3_resource: resource, bucket: settings.bucket, key: get_key,
            file_path:, content_type: 'application/json',
            return_object: true
          )

        expires_in = EXPIRY_DURATION.to_i
        object.presigned_url(:get, expires_in:)
      end

      def get_key
        "#{@filter}-#{@now.to_i}.json"
      end

      def write_file(file, each_submission)
        file.write('[')

        first = true
        each_submission.each do |submission|
          file.write(',') unless first
          file.write(submission.to_json)
          first = false
        end

        file.write(']')
        file.flush
        file.rewind
      end
    end
  end
end
