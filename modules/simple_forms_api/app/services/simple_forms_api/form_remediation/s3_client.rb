# frozen_string_literal: true

require_relative 'file_utilities'

# Built in accordance with the following documentation:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md
module SimpleFormsApi
  module FormRemediation
    class S3Client
      include FileUtilities

      class << self
        def fetch_presigned_url(id, config:, type: :submission)
          new(id:, config:, type:).retrieve_presigned_url
        end
      end

      def initialize(config:, type: :remediation, **options)
        @upload_type = type
        @config = config
        @id = options[:id]
        @parent_dir = config.parent_dir

        assign_defaults(options)
        log_initialization
      rescue => e
        config.handle_error('S3 Client initialization failed', e)
      end

      def upload
        config.log_info("Uploading #{upload_type}: #{id} to S3 bucket")

        upload_to_s3(archive_path)
        update_manifest if manifest_required?
        cleanup!(archive_path)

        return generate_presigned_url if presign_required?

        id
      rescue => e
        config.handle_error("Failed #{upload_type} upload: #{id}", e)
      end

      def retrieve_presigned_url
        archive = config.submission_archive_class.new(config:, id:, type: upload_type)
        @archive_path, @manifest_row = archive.retrieval_data
        generate_presigned_url(type: upload_type)
      end

      private

      attr_reader :archive_path, :config, :id, :manifest_row, :parent_dir, :temp_directory_path, :upload_type

      def assign_defaults(options)
        @file_path = options[:file_path]
        @archive_path, @manifest_row = build_archive!(config:, type: upload_type, **options)
        @temp_directory_path = File.dirname(archive_path)
      rescue => e
        config.handle_error('Failed to assign defaults during S3 Client initialization', e)
      end

      def log_initialization
        config.log_info("Initialized S3 Client for #{upload_type} with ID: #{id}")
      end

      def build_archive!(**)
        config.submission_archive_class.new(**).build!
      end

      def upload_to_s3(local_path, type: upload_type)
        return if File.directory?(local_path)

        File.open(local_path) do |file_obj|
          sanitized_file = CarrierWave::SanitizedFile.new(file_obj)
          s3_uploader.store!(sanitized_file)
          config.log_info("Successfully uploaded #{type}: #{sanitized_file.filename} to S3 bucket")
        end
      end

      def update_manifest
        form_number = manifest_row[1]
        if form_number.blank?
          config.handle_error('Manifest update failed: form_number is missing or invalid.')
          return
        end

        temp_dir = Rails.root.join("tmp/#{SecureRandom.hex}-manifest/").to_s
        create_directory!(temp_dir)
        begin
          s3_path = build_s3_manifest_path
          local_path = download_manifest(temp_dir, s3_path)
          write_and_upload_manifest(local_path) if config.include_manifest
        ensure
          cleanup!(temp_dir)
        end
      rescue => e
        config.handle_error('Failed to update manifest', e)
      end

      def build_s3_manifest_path
        path = build_path(:file, s3_directory_path, "manifest_#{container_directory}", ext: '.csv')
        path.sub(%r{^/}, '')
      end

      def download_manifest(dir, s3_path)
        local_path = File.join(dir, s3_path)
        create_directory!(File.dirname(local_path))
        s3_uploader.get_s3_file(s3_path, local_path)
        local_path
      end

      def write_and_upload_manifest(local_path)
        write_manifest(manifest_row, local_path)
        upload_to_s3(local_path, type: :manifest)
      end

      def s3_uploader
        @s3_uploader ||= config.uploader_class.new(config:, directory: s3_directory_path)
      end

      def s3_directory_path
        @s3_directory_path ||= build_path(:dir, parent_dir, upload_type.to_s, container_directory)
      end

      # /path/to/parent_dir/<UPLOAD_TYPE>/<SUBMISSION_DATE>-Form<FORM_NUMBER>
      def container_directory
        date = upload_type == :submission ? manifest_row[0] : Time.zone.today
        dated_directory_name(manifest_row[1], date)
      end

      def generate_presigned_url(type: upload_type)
        s3_uploader.get_s3_link(s3_upload_file_path(type))
      end

      def s3_upload_file_path(type)
        extension = File.extname(archive_path)
        ext = type == :submission ? '.pdf' : '.zip'
        build_path(:file, s3_directory_path, File.basename(archive_path), ext: extension ? nil : ext)
      end

      def presign_required?
        return true if upload_type == :submission

        config.presign_s3_url
      end

      def manifest_required?
        config.include_manifest && upload_type == :remediation
      end
    end
  end
end
