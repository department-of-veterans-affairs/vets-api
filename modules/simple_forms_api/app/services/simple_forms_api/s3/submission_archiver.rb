# frozen_string_literal: true

require 'csv'
require 'fileutils'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiver < Utils
      class << self
        def fetch_presigned_url(benefits_intake_uuid, type: :submission)
          new(benefits_intake_uuid:).generate_presigned_url(s3_upload_file_path, type:)
        end
      end

      def initialize(parent_dir: 'vff-simple-forms', **options) # rubocop:disable Lint/MissingSuper
        @parent_dir = parent_dir
        defaults = default_options.merge(options)
        @temp_directory_path, @submission, @unique_filename = build_submission_archive(**defaults)
        raise 'Failed to build SubmissionArchive.' unless temp_directory_path && submission

        assign_instance_variables(defaults)
      rescue => e
        handle_error('SubmissionArchiver initialization failed', e)
      end

      def upload(type: :remediation)
        log_info("Uploading #{type}: #{benefits_intake_uuid} to S3 bucket")

        @upload_type = type

        zip_directory! if upload_type == :remediation

        upload_file_to_s3
        cleanup
        generate_presigned_url(build_path(s3_directory_path, local_upload_file_path.split('/').last))
      rescue => e
        handle_error("Failed #{type} upload: #{benefits_intake_uuid}", e)
      end

      def cleanup
        FileUtils.rm_rf(local_upload_file_path)
      end

      private

      attr_reader :benefits_intake_uuid, :parent_dir, :submission, :temp_directory_path, :unique_filename, :upload_type

      def default_options
        {
          attachments: nil,           # The confirmation codes of any attachments which were originally submitted
          benefits_intake_uuid: nil,  # The UUID returned from the Benefits Intake API upon original submission
          file_path: nil,             # The local path where the submission PDF is stored
          metadata: nil,              # Data appended to the original submission headers
          submission: nil             # The FormSubmission object representing the original data payload submitted
        }
      end

      def s3_uploader
        @s3_uploader ||= VeteranFacingFormsRemediationUploader.new(benefits_intake_uuid, s3_directory_path)
      end

      def build_submission_archive(**)
        SubmissionArchiveBuilder.new(**).run
      end

      def generate_presigned_url(*, **)
        VeteranFacingFormsRemediationUploader.get_s3_link(build_path(*, **))
      end

      def zip_directory!(dir_path = temp_directory_path)
        raise "Directory not found: #{dir_path}" unless File.directory?(dir_path)

        Zip::File.open(local_upload_file_path, Zip::File::CREATE) do |zipfile|
          Dir.chdir(dir_path) do
            Dir['**', '*'].each do |file|
              next if File.directory?(file)

              zipfile.add(file, File.join(dir_path, file)) if File.file?(file)
            end
          end
        end

        local_upload_file_path
      rescue => e
        handle_error("Failed to zip temp directory: #{temp_directory_path} to location: #{local_upload_file_path}", e)
      end

      def upload_file_to_s3
        return if File.directory?(local_upload_file_path)

        File.open(local_upload_file_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
        end
      end

      def s3_directory_path
        @s3_directory_path ||= build_path(parent_dir, upload_type.to_s, is_file: false)
      end

      def s3_upload_file_path
        @s3_upload_file_path ||= build_path(s3_directory_path, "#{unique_filename}.ext")
      end

      def build_local_file_dir!(s3_key, dir_path = temp_directory_path)
        local_path = Pathname.new(s3_key).relative_path_from(Pathname.new(s3_directory_path))
        final_path = Pathname.new(dir_path).join(local_path)

        FileUtils.mkdir_p(final_path.dirname)
        final_path.to_s
      end

      def local_upload_file_path
        @local_upload_file_path ||= build_local_file_dir!(s3_upload_file_path)
      end

      def build_path(base_dir, *, type: upload_type, is_file: true)
        file_ext = type == :submission ? '.pdf' : '.zip'
        ext = is_file ? file_ext : ''
        path = Pathname.new(base_dir.to_s).join(*).sub_ext(ext)
        path.to_s
      end
    end
  end
end
