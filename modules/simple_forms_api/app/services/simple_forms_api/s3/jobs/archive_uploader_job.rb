# frozen_string_literal: true

require 'zip'
require 'aws-sdk-s3'

module SimpleFormsApi
  module S3
    module Jobs
      class ArchiveUploaderJob < SimpleFormsApi::S3::Utils
        include Sidekiq::Worker

        sidekiq_options retry: 3, queue: 'default'

        def perform(benefits_intake_uuid:)
          @benefits_intake_uuid = benefits_intake_uuid

          @zip_path = SubmissionArchiver.fetch_s3_submission(benefits_intake_uuid)

          zip_folder

          ArchiveUploader.upload(zip_file_path: @zip_path)

          FileUtils.rm_rf(temp_directory_path)
        rescue => e
          handle_error('ArchiveUploaderJob failed.', e)
        end

        private

        attr_reader :benefits_intake_uuid

        def zip_folder
          Zip::File.open(temp_directory_path, Zip::File::CREATE) do |zip_file|
            Dir[File.join(temp_directory_path, '**', '**')].each do |file|
              zip_file.add(file.sub("#{temp_directory_path}/", ''), file)
            end
          end
        end
      end
    end
  end
end
