# frozen_string_literal: true

module Common
  module S3Helpers
    # PORO for handling S3 file uploads with TransferManager support
    class Uploader
      attr_reader :s3_resource, :bucket, :key, :file_path, :options

      def initialize(s3_resource:, bucket:, key:, file_path:, **options)
        @s3_resource = s3_resource
        @bucket = bucket
        @key = key
        @file_path = file_path
        @options = options
      end

      def upload
        if use_transfer_manager?
          upload_with_transfer_manager
        else
          upload_with_basic_method
        end

        return_object? ? s3_object : true
      end

      private

      def use_transfer_manager?
        Aws::S3.const_defined?(:TransferManager)
      end

      def upload_with_transfer_manager
        Aws::S3::TransferManager.new(client: s3_resource.client).upload_file(
          file_path,
          bucket:,
          key:,
          **transfer_manager_options
        )
      end

      def upload_with_basic_method
        s3_object.upload_file(file_path, **basic_upload_options)
      end

      def transfer_manager_options
        {
          content_type: options[:content_type],
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        }.merge(optional_upload_options)
      end

      def basic_upload_options
        { content_type: options[:content_type] }.merge(optional_upload_options)
      end

      def optional_upload_options
        {}.tap do |opts|
          opts[:acl] = options[:acl] if options[:acl]
          opts[:server_side_encryption] = options[:server_side_encryption] if options[:server_side_encryption]
        end
      end

      def s3_object
        @s3_object ||= s3_resource.bucket(bucket).object(key)
      end

      def return_object?
        options[:return_object]
      end
    end

    # Module function wrapper for backward compatibility
    module_function

    # Upload a file to S3 using TransferManager if available, falling back to basic upload.
    #
    # @param s3_resource [Aws::S3::Resource] The S3 resource to use for upload
    # @param bucket [String] The S3 bucket name
    # @param key [String] The S3 object key (path/filename in the bucket)
    # @param file_path [String] The local file path to upload
    # @param options [Hash] Upload options (content_type required, acl/server_side_encryption/return_object optional)
    # @return [Aws::S3::Object, Boolean] The S3 object if return_object is true, otherwise true
    def upload_file(s3_resource:, bucket:, key:, file_path:, **)
      Uploader.new(s3_resource:, bucket:, key:, file_path:, **).upload
    end
  end
end
