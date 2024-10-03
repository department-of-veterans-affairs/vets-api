# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'simple_forms_api/form_submission_remediation/configuration/base'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module S3
    class S3Client
      DEFAULT_CONFIG = SimpleFormsApi::FormSubmissionRemediation::Configuration::Base.new

      class << self
        def fetch_presigned_url(id, type: :submission)
          new(id:).s3_generate_presigned_url(s3_upload_file_path, type:)
        end
      end

      def initialize(config: DEFAULT_CONFIG, type: :remediation, **options)
        @upload_type = type
        @config = config
        @parent_dir = config.parent_dir
        @presign_s3_url = config.presign_s3_url
        @temp_directory_path = config.temp_directory_path

        @file_path = options[:file_path]
        @id = options[:id]

        build_archive!(config:, type:, **options)
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def upload
        config.log_info("Uploading #{type}: #{id} to S3 bucket")

        upload_to_s3
        FileUtilities.cleanup

        presign_s3_url ? s3_generate_presigned_url(s3_get_presigned_path) : id
      rescue => e
        config.handle_error("Failed #{type} upload: #{id}", e)
      end

      private

      attr_reader :config, :id, :parent_dir, :presign_s3_url, :temp_directory_path, :unique_filename, :upload_type

      def build_archive!(**)
        archive_data = config.submission_archive_class.new(**).build!
        assign_archive_data(archive_data)
      end

      def assign_archive_data(archive_data)
        @unique_filename = archive_data
        raise 'Failed to build SubmissionArchive.' unless temp_directory_path
      end

      def upload_to_s3
        return if File.directory?(local_file_path)

        File.open(local_file_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
        end
      end

      def s3_uploader
        @s3_uploader ||= config.uploader.new(config:, directory: s3_directory_path)
      end

      def s3_directory_path
        @s3_directory_path ||= new_path(parent_dir, upload_type.to_s, is_file: false)
      end

      def s3_upload_file_path
        @s3_upload_file_path ||= new_path(s3_directory_path, "#{unique_filename}.ext")
      end

      def s3_get_presigned_path
        new_path(s3_directory_path, local_file_path.split('/').last)
      end

      def s3_generate_presigned_url(s3_path)
        config.uploader.get_s3_link(s3_path)
      end

      def local_file_path
        FileUtilities.local_upload_file_path
      end

      def new_path(*, type: upload_type, **)
        FileUtilities.build_path(*, type:, **)
      end
    end
  end
end
