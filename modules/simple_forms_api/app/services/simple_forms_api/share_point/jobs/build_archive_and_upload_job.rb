# frozen_string_literal: true

require 'zip'

module SimpleFormsApi
  module SharePoint
    module Jobs
      class BuildArchiveAndUploadJob < SimpleFormsApi::S3::Utils
        include Sidekiq::Worker

        sidekiq_options retry: 3, queue: 'default'

        def perform(benefits_intake_uuid:)
          @benefits_intake_uuid = benefits_intake_uuid

          temp_directory_path = build_submission_archive
          zip_temp_folder(temp_directory_path)
          upload_folder_to_sharepoint(temp_directory_path)

          FileUtils.rm_rf(temp_directory_path)
        rescue => e
          handle_error('BuildArchiveAndUploadJob failed.', e)
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

        def build_submission_archive
          SubmissionArchiveBuilder.new(benefits_intake_uuid:).run
        end

        def upload_folder_to_sharepoint(zip_file_path)
          SimpleFormsApi::SharePoint::ArchiveUploader.upload(benefits_intake_uuid:, zip_file_path:)
        end
      end
    end
  end
end
