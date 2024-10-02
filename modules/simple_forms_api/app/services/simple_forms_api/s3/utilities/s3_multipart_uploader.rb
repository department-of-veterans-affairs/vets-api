# frozen_string_literal: true

module SimpleFormsApi
  module S3
    module Utilities
      class S3MultipartUploader
        PART_SIZE = 100 * 1024 * 1024 # 100 MB chunks

        def initialize(file_path)
          @file_path = file_path
          @s3_object = VeteranFacingFormsRemediationUploader.new_s3_object(file_path)
        end

        def upload
          validate_file_path

          File.open(file_path, 'rb') do |file_obj|
            multipart_upload = initiate_upload
            upload_id = multipart_upload.id

            begin
              parts = upload_file_parts(file_obj, upload_id)
              complete_upload(upload_id, parts)
              log_info('File uploaded successfully.')
            rescue => e
              abort_upload(upload_id)
              log_error('Multipart upload aborted', e)
            end
          end
        end

        private

        attr_reader :file_path, :s3_object

        def validate_file_path
          raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
        end

        def initiate_upload
          s3_object.initiate_multipart_upload
        end

        def upload_file_parts(file_obj, upload_id)
          parts = []
          part_number = 1

          while (part_data = file_obj.read(PART_SIZE))
            response = upload_part(part_data, part_number, upload_id)
            parts << { part_number:, etag: response.etag }
            part_number += 1
          end

          parts
        end

        def upload_part(part_data, part_number, upload_id)
          log_info("Uploading part #{part_number}")
          s3_object.upload_part(body: part_data, part_number:, upload_id:)
        rescue => e
          handle_error("Failed to upload part #{part_number}: #{e.message}", e)
        end

        def complete_upload(upload_id, parts)
          log_info("Completing upload for ID: #{upload_id}")
          s3_object.complete_multipart_upload(upload_id:, multipart_upload: { parts: })
        rescue => e
          handle_error("Failed to complete upload: #{e.message}", e)
        end

        def abort_upload(upload_id)
          log_warning("Aborting upload for ID: #{upload_id}")
          s3_object.abort_multipart_upload(upload_id:)
        rescue => e
          log_error("Failed to abort upload: #{e.message}", e)
        end
      end
    end
  end
end
