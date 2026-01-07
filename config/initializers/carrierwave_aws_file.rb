# frozen_string_literal: true

Rails.application.config.after_initialize do
  if Flipper.enabled?(:carrierwave_storage_aws_file)
    module CarrierWave
      module Storage
        class AWSFile
          def store(new_file)
            if new_file.is_a?(self.class)
              new_file.move_to(path)
            elsif Aws::S3.const_defined?(:TransferManager)
              options = aws_options.write_options(new_file).except(:body)
              # MULTIPART_TRESHOLD was renamed to MULTIPART_THRESHOLD https://github.com/carrierwaveuploader/carrierwave-aws/commit/1117b0e1ccd2b653717136d846814d9a64aa5d72
              # MULTIPART_TRESHOLD will have to be renamed when upgrading carrierwave
              options[:multipart_threshold] = CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
              Aws::S3::TransferManager.new(client: connection.client).upload_file(new_file.path, bucket: bucket.name,
                                                                                                 key: path, **options)
            else
              file.upload_file(new_file.path, aws_options.write_options(new_file))
            end
          end
        end
      end
    end
  end
end
