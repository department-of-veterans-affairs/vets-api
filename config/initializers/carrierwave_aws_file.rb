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
              options[:multipart_threshold] = AWSOptions::MULTIPART_THRESHOLD
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
