# frozen_string_literal: true

module PdfUpload
  class S3Uploader
    ALLOWED_EXTENSIONS = %w[pdf].freeze
    MAX_FILE_SIZE = 150.megabytes

    class UploadError < StandardError; end
    class ValidationError < StandardError; end

    def initialize(directory:, config:)
      raise ValidationError, 'The S3 directory is missing.' if directory.blank?
      raise ValidationError, 'The configuration is missing.' unless config

      @directory = directory
      @config = config
    end

    def store!(file)
      raise ValidationError, 'Invalid file object provided for upload.' unless file.respond_to?(:read)

      filename = extract_filename(file)
      validate_file!(file, filename)

      s3_client.put_object(
        bucket: bucket_name,
        key: s3_key(filename),
        body: file.read,
        server_side_encryption: 'AES256',
        acl: 'private'
      )
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error("S3 upload failed for #{filename}: #{e.message}")
      raise UploadError, "Upload failed: #{e.message}"
    end

    def get_s3_link(file_path, filename = nil)
      filename ||= File.basename(file_path)

      presigner.presigned_url(
        :get_object,
        bucket: bucket_name,
        key: file_path,
        expires_in: 30.minutes.to_i,
        response_content_disposition: "attachment; filename=\"#{filename}\""
      )
    end

    private

    attr_reader :config, :directory

    def extract_filename(file)
      if file.respond_to?(:original_filename) && file.original_filename.present?
        file.original_filename
      elsif file.respond_to?(:path) && file.path.present?
        File.basename(file.path)
      else
        raise ValidationError, 'Cannot determine filename from file object.'
      end
    end

    def validate_file!(file, filename)
      ext = File.extname(filename).delete('.').downcase
      raise ValidationError, "File extension '#{ext}' not allowed" unless ALLOWED_EXTENSIONS.include?(ext)

      return unless file.respond_to?(:size) && file.size > MAX_FILE_SIZE

      raise ValidationError, "File exceeds maximum size of #{MAX_FILE_SIZE} bytes"
    end

    def s3_key(filename)
      "#{directory}/#{filename}"
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(region: config.region)
    end

    def presigner
      @presigner ||= Aws::S3::Presigner.new(client: s3_client)
    end

    def bucket_name
      config.bucket
    end
  end
end
