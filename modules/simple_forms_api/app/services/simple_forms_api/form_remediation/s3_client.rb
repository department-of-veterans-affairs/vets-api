# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'simple_forms_api/form_remediation/configuration/base'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module FormRemediation
    class S3Client
      include FileUtilities

      class << self
        def fetch_presigned_url(id, type: :submission)
          new(id:).s3_generate_presigned_url(s3_upload_file_path, type:)
        end
      end

      def initialize(config: Configuration::Base.new, type: :remediation, **options)
        @upload_type = type
        @config = config
        @parent_dir = config.parent_dir
        @presign_s3_url = config.presign_s3_url
        @temp_directory_path = config.temp_directory_path

        @file_path = options[:file_path]
        @id = options[:id]

        @archive_path = build_archive!(config:, type:, **options)
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def upload
        config.log_info("Uploading #{upload_type}: #{id} to S3 bucket")

        upload_to_s3
        cleanup(s3_upload_file_path)

        presign_s3_url ? s3_generate_presigned_url(s3_get_presigned_path) : id
      rescue => e
        config.handle_error("Failed #{upload_type} upload: #{id}", e)
      end

      private

      attr_reader :archive_path, :config, :id, :parent_dir, :presign_s3_url, :temp_directory_path, :upload_type

      def build_archive!(**)
        config.submission_archive_class.new(**).build!
      end

      def upload_to_s3
        return if File.directory?(local_file_path)

        File.open(local_file_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
        end
      end

      def s3_uploader
        @s3_uploader ||= config.uploader_class.new(config:, directory: s3_directory_path)
      end

      def s3_directory_path
        @s3_directory_path ||= build_path(:dir, parent_dir, upload_type.to_s)
      end

      def s3_upload_file_path
        @s3_upload_file_path ||= build_path(:file, s3_directory_path, "#{archive_path}.ext")
      end

      def s3_get_presigned_path
        build_path(:file, s3_directory_path, local_file_path.split('/').last)
      end

      def s3_generate_presigned_url(s3_path)
        config.uploader_class.get_s3_link(s3_path)
      end

      def local_file_path
        @local_file_path ||= create_local_file_path(s3_upload_file_path, temp_directory_path, s3_directory_path)
      end
    end
  end
end
