# frozen_string_literal: true

module Common
  module S3Helpers
    module_function

    # Upload a file to S3 using TransferManager if available, falling back to basic upload.
    #
    # @param s3_resource [Aws::S3::Resource] The S3 resource to use for upload
    # @param bucket [String] The S3 bucket name
    # @param key [String] The S3 object key (path/filename in the bucket)
    # @param file_path [String] The local file path to upload
    # @param options [Hash] Upload options (content_type required, acl/server_side_encryption/return_object optional)
    # @return [Aws::S3::Object, Boolean] The S3 object if return_object is true, otherwise true
    def upload_file(s3_resource:, bucket:, key:, file_path:, **options)
      upload_params = { s3_resource:, bucket:, key:, file_path:, options: }

      if Aws::S3.const_defined?(:TransferManager)
        upload_with_transfer_manager(upload_params)
      else
        upload_with_basic_method(upload_params)
      end

      options[:return_object] ? s3_resource.bucket(bucket).object(key) : true
    end

    def upload_with_transfer_manager(params)
      options = params[:options]
      upload_options = {
        content_type: options[:content_type],
        multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
      }
      upload_options[:acl] = options[:acl] if options[:acl]
      if options[:server_side_encryption]
        upload_options[:server_side_encryption] =
          options[:server_side_encryption]
      end

      Aws::S3::TransferManager.new(client: params[:s3_resource].client).upload_file(
        params[:file_path],
        bucket: params[:bucket],
        key: params[:key],
        **upload_options
      )
    end

    def upload_with_basic_method(params)
      obj = params[:s3_resource].bucket(params[:bucket]).object(params[:key])
      options = params[:options]
      upload_options = { content_type: options[:content_type] }
      upload_options[:acl] = options[:acl] if options[:acl]
      if options[:server_side_encryption]
        upload_options[:server_side_encryption] =
          options[:server_side_encryption]
      end
      obj.upload_file(params[:file_path], **upload_options)
    end
  end
end
