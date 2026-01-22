# frozen_string_literal: true

# rubocop:disable Lint/ConstantDefinitionInBlock
Rails.application.config.after_initialize do
  module CarrierWave
    module Storage
      class AWSFile
        ALLOWED_UPLOAD_OPTIONS = %i[
          acl multipart_threshold content_type cache_control content_disposition
          content_encoding content_language expires server_side_encryption
          storage_class metadata ssekms_key_id sse_customer_algorithm
          sse_customer_key sse_customer_key_md5 tagging checksum_algorithm
          content_md5 bucket_key_enabled
        ].freeze

        def store(new_file)
          if new_file.is_a?(self.class)
            new_file.move_to(path)
          elsif Aws::S3.const_defined?(:TransferManager)
            options = aws_options.write_options(new_file).except(:body)

            # MULTIPART_TRESHOLD was renamed to MULTIPART_THRESHOLD
            # https://github.com/carrierwaveuploader/carrierwave-aws/commit/1117b0e1ccd2b653717136d846814d9a64aa5d72
            options[:multipart_threshold] = CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD

            # Filter to only the options upload_file accepts
            upload_options = options.slice(*ALLOWED_UPLOAD_OPTIONS)

            Aws::S3::TransferManager.new(client: connection.client).upload_file(
              new_file.path,
              bucket: bucket.name,
              key: path,
              **upload_options
            )
          else
            file.upload_file(new_file.path, aws_options.write_options(new_file))
          end
        end
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock
