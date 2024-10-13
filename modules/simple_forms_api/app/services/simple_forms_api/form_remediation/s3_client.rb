# frozen_string_literal: true

require_relative 'file_utilities'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module FormRemediation
    class S3Client
      include FileUtilities

      class << self
        def fetch_presigned_url(id, type: :submission)
          new(id:).generate_presigned_url(type:)
        end
      end

      def initialize(config:, type: :remediation, **options)
        @upload_type = type
        @config = config
        @id = options[:id]

        assign_defaults(options)
        initialize_archive
        log_initialization
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def upload
        config.log_info("Uploading #{upload_type}: #{id} to S3 bucket")

        upload_to_s3(archive_path)
        update_manifest if config.include_manifest
        cleanup(archive_path)

        return generate_presigned_url if presign_required?

        id
      rescue => e
        config.handle_error("Failed #{upload_type} upload: #{id}", e)
      end

      private

      attr_reader :archive_path, :config, :id, :manifest_row, :parent_dir, :temp_directory_path, :upload_type

      def assign_defaults(options)
        @file_path = options[:file_path]
        @archive_path, @manifest_row = build_archive!(config:, type: upload_type, **options)
        @temp_directory_path = File.dirname(archive_path)
      end

      def initialize_archive
        @parent_dir = config.parent_dir
      end

      def log_initialization
        config.log_info("Initialized S3Client for #{upload_type} with ID: #{id}")
      end

      def build_archive!(**)
        config.submission_archive_class.new(**).build!
      end

      def upload_to_s3(local_path)
        return if File.directory?(local_path)

        File.open(local_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
        end
      end

      def update_manifest
        form_number = manifest_row[1]
        local_path = fetch_or_create_manifest(form_number)
        write_and_upload_manifest(local_path)
      rescue => e
        config.handle_error('Failed to update manifest', e)
      end

      def fetch_or_create_manifest(form_number)
        s3_path = build_s3_manifest_path(form_number)
        local_path = create_local_path(s3_path)
        existing_manifest = s3_uploader.get_s3_file(s3_path, local_path)
        CSV.open(local_path, 'w') if existing_manifest.blank?
        local_path
      end

      def build_s3_manifest_path(form_number)
        path = build_path(:file, s3_directory_path, "manifest_#{dated_directory_name(form_number)}", ext: '.csv')
        path.sub(%r{^/}, '')
      end

      def create_local_path(s3_path)
        Dir.mktmpdir do |dir|
          local_path = File.join(dir, s3_path)
          FileUtils.mkdir_p(File.dirname(local_path))
          local_path
        end
      end

      def write_and_upload_manifest(local_path)
        write_manifest(manifest_row, !File.exist?(local_path), local_path)
        upload_to_s3(local_path)
      end

      def s3_uploader
        @s3_uploader ||= config.uploader_class.new(config:, directory: s3_directory_path)
      end

      def s3_directory_path
        @s3_directory_path ||= build_path(:dir, parent_dir, upload_type.to_s, dated_directory_name(manifest_row[1]))
      end

      def generate_presigned_url(type: upload_type)
        s3_uploader.get_s3_link(s3_upload_file_path(type))
      end

      def s3_upload_file_path(type)
        ext = type == :submission ? '.pdf' : '.zip'
        build_path(:file, s3_directory_path, archive_path, ext:)
      end

      def presign_required?
        config.presign_s3_url
      end
    end
  end
end
