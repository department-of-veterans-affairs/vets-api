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
    # @param content_type [String] The MIME type for the uploaded file
    # @param acl [String, nil] The ACL for the uploaded file (e.g., 'public-read'), nil for default
    # @param return_object [Boolean] If true, returns the S3 object; if false, returns true on success
    # @return [Aws::S3::Object, Boolean] The S3 object if return_object is true, otherwise true
    def upload_file(s3_resource:, bucket:, key:, file_path:, content_type:, acl: nil, return_object: false)
      if Aws::S3.const_defined?(:TransferManager)
        # Use TransferManager for efficient multipart uploads
        options = {
          content_type:,
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        }
        options[:acl] = acl if acl

        Aws::S3::TransferManager.new(client: s3_resource.client).upload_file(
          file_path,
          bucket:,
          key:,
          **options
        )
      else
        # Fall back to basic upload
        obj = s3_resource.bucket(bucket).object(key)
        upload_options = { content_type: }
        upload_options[:acl] = acl if acl
        obj.upload_file(file_path, **upload_options)
      end

      return_object ? s3_resource.bucket(bucket).object(key) : true
    end
  end
end
