# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    class Uploader < CarrierWave::Uploader::Base
      include UploaderVirusScan

      def size_range
        (1.byte)...(150.megabytes)
      end

      # Allowed file types, including those specific to benefits intake
      def extension_allowlist
        %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
      end

      def content_type_allowlist
        [
          'image/bmp',         # bmp
          'text/csv',          # csv
          'image/gif',         # gif
          'image/jpeg',        # jpeg
          'image/jpg',         # jpg
          'application/json',  # json
          'application/pdf',   # pdf
          'image/png',         # png
          'image/tiff',        # tif, tiff
          'text/plain',        # txt
          'application/zip'    # zip
        ]
      end

      def initialize(directory:, config:)
        raise 'The S3 directory is missing.' if directory.blank?
        raise 'The configuration is missing.' unless config

        @config = config
        @directory = directory

        super()
        set_storage_options!
      end

      def store_dir
        @directory
      end

      def get_s3_link(file_path, filename = nil)
        filename ||= File.basename(file_path)
        s3_obj(file_path).presigned_url(
          :get,
          expires_in: 30.minutes.to_i,
          response_content_disposition: "attachment; filename=\"#{filename}\""
        )
      end

      def get_s3_file(from_path, to_path)
        s3_obj(from_path).get(response_target: to_path)
      rescue Aws::S3::Errors::NoSuchKey
        nil
      rescue => e
        config.handle_error('An error occured while downloading the file.', e)
      end

      private

      attr_reader :config

      def s3_obj(file_path)
        client = Aws::S3::Client.new(stub_responses: Rails.env.test?)
        resource = Aws::S3::Resource.new(client:)
        resource.bucket(config.s3_settings.bucket).object(file_path)
      end

      def set_storage_options!
        settings = config.s3_settings

        self.aws_credentials = {
          region: settings.region
          # retry_mode: 'standard', # Use 'standard' or 'adaptive' for better retry handling
          # retry_limit: 3 # Maximum retry attempts
        }
        self.aws_acl = 'private'
        self.aws_bucket = settings.bucket
        self.aws_attributes = {
          server_side_encryption: 'AES256',
          retry_mode: 'standard', # Use 'standard' or 'adaptive' for better retry handling
          retry_limit: 3 # Maximum retry attempts
        }
        self.class.storage = :aws
      end
    end
  end
end
