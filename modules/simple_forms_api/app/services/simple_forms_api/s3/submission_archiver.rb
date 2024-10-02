# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'simple_forms_api/form_submission_remediation/configuration/base'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class SubmissionArchiver
      class << self
        def fetch_presigned_url(id, type: :submission)
          new(id:).generate_presigned_url(s3_upload_file_path, type:)
        end
      end

      def initialize(**options)
        @config = options[:config] || SimpleFormsApi::FormSubmissionRemediation::Configuration::Base.new
        @parent_dir = config.parent_dir
        @presign_s3_url = config.presign_s3_url

        assign_defaults(options)

        build_archive!(**options)
      rescue => e
        config.handle_error('SubmissionArchiver initialization failed', e)
      end

      def upload(type: :remediation)
        config.log_info("Uploading #{type}: #{id} to S3 bucket")

        @upload_type = type

        zip_directory! if upload_type == :remediation

        upload_to_s3
        cleanup_temp_files

        presign_s3_url ? generate_presigned_url(s3_get_presigned_path) : id
      rescue => e
        config.handle_error("Failed #{type} upload: #{id}", e)
      end

      def cleanup_temp_files
        FileUtils.rm_rf(local_upload_file_path)
      end

      private

      attr_reader :config, :id, :parent_dir, :presign_s3_url, :submission, :temp_directory_path, :unique_filename,
                  :upload_type

      def assign_defaults(options)
        # The confirmation codes of any attachments which were originally submitted
        @attachments = options[:attachments]
        # The local path where the submission PDF is stored
        @file_path = options[:file_path]
        # The UUID returned from the Benefits Intake API upon original submission
        @id = options[:id]
        # Data appended to the original submission headers
        @metadata = options[:metadata]
        # The FormSubmission object representing the original data payload submitted
        @submission = options[:submission]
      end

      def build_archive!(**)
        archive_data = config.archive_builder.new(**).run
        assign_archive_data(archive_data)
      end

      def assign_archive_data(archive_data)
        @temp_directory_path, @submission, @unique_filename = archive_data
        raise 'Failed to build SubmissionArchive.' unless temp_directory_path && submission
      end

      def zip_directory!
        raise "Directory not found: #{temp_directory_path}" unless File.directory?(temp_directory_path)

        Zip::File.open(local_upload_file_path, Zip::File::CREATE) do |zipfile|
          Dir.chdir(temp_directory_path) do
            Dir['**', '*'].each do |file|
              next if File.directory?(file)

              zipfile.add(file, File.join(temp_directory_path, file)) if File.file?(file)
            end
          end
        end

        local_upload_file_path
      rescue => e
        config.handle_error(
          "Failed to zip temp directory: #{temp_directory_path} to location: #{local_upload_file_path}", e
        )
      end

      def upload_to_s3
        return if File.directory?(local_upload_file_path)

        File.open(local_upload_file_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
        end
      end

      def s3_uploader
        @s3_uploader ||= config.uploader.new(id, s3_directory_path)
      end

      def s3_directory_path
        @s3_directory_path ||= build_path(parent_dir, upload_type.to_s, is_file: false)
      end

      def s3_upload_file_path
        @s3_upload_file_path ||= build_path(s3_directory_path, "#{unique_filename}.ext")
      end

      def s3_get_presigned_path
        build_path(s3_directory_path, local_upload_file_path.split('/').last)
      end

      def generate_presigned_url(s3_path)
        config.uploader.get_s3_link(s3_path)
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
