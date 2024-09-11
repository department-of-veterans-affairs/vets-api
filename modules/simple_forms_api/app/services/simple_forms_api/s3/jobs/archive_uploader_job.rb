# frozen_string_literal: true

require 'zip'

module SimpleFormsApi
  module S3
    module Jobs
      class ArchiveUploaderJob < SimpleFormsApi::S3::Utils
        include Sidekiq::Worker

        sidekiq_options retry: 3, queue: 'default'

        def perform(benefits_intake_uuid:)
          @benefits_intake_uuid = benefits_intake_uuid

          temp_directory_path = fetch_s3_folder
          zip_temp_folder(temp_directory_path)
          upload_s3_folder_to_sharepoint(temp_directory_path)

          FileUtils.rm_rf(temp_directory_path)
        rescue => e
          handle_error('ArchiveUploaderJob failed.', e)
        end

        private

        attr_reader :benefits_intake_uuid

        def zip_temp_folder(temp_directory_path)
          Zip::File.open(temp_directory_path, Zip::File::CREATE) do |zip_file|
            Dir[File.join(temp_directory_path, '**', '**')].each do |file|
              zip_file.add(file.sub("#{temp_directory_path}/", ''), file)
            end
          end
        end

        def fetch_s3_folder
          SimpleFormsApi::S3::SubmissionArchiver.fetch_s3_submission(benefits_intake_uuid)
        end

        def upload_s3_folder_to_sharepoint(zip_file_path)
          SimpleFormsApi::SharePoint::ArchiveUploader.upload(benefits_intake_uuid:, zip_file_path:)
        end
      end
    end
  end
end
