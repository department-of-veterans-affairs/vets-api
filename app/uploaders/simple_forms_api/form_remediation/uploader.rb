# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    class Uploader < CarrierWave::Uploader::Base
      include UploaderVirusScan

      class << self
        def s3_settings
          config = Configuration::Base.new
          config.s3_settings
        end

        def new_s3_resource
          client = Aws::S3::Client.new(region: s3_settings.region)
          Aws::S3::Resource.new(client:)
        end

        def get_s3_link(file_path)
          new_s3_resource.bucket(s3_settings.bucket)
                         .object(file_path)
                         .presigned_url(:get, expires_in: 30.minutes.to_i)
        end
      end

      def size_range
        (1.byte)...(150.megabytes)
      end

      # Allowed file types, including those specific to benefits intake
      def extension_allowlist
        %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
      end

      def initialize(directory:, config: Configuration::Base.new)
        raise 'The S3 directory is missing.' if directory.blank?

        @config = config
        @directory = directory

        super()
        set_storage_options!
      end

      def store_dir
        @directory
      end

      private

      def set_storage_options!
        settings = @config.s3_settings

        self.aws_credentials = { region: settings.region }
        self.aws_acl = 'private'
        self.aws_bucket = settings.bucket
        self.aws_attributes = { server_side_encryption: 'AES256' }
        self.class.storage = :aws
      end
    end
  end
end
