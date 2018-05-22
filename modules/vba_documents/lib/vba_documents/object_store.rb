# frozen_string_literal: true

module VBADocuments
  class ObjectStore
    # Obtain the configured VBADocuments bucket
    def bucket
      @bucket ||= begin
        s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                   access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                   secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        s3.bucket(Settings.vba_documents.s3.bucket)
      end
    end

    # Obtain a specified object from the VBADocuments bucket
    delegate :object, to: :bucket

    # Obtain the first ObjectVersion for a given key.
    def first_version(key)
      versions = bucket.object_versions(prefix: key)
      versions.sort_by(&:last_modified).first
    end

    # Streams the contents of a given ObjectVersion directly to the
    # specified path.
    def download(object_version, path)
      client.get_object(bucket: object_version.bucket_name,
                        key: object_version.object_key,
                        version_id: object_version.version_id,
                        response_target: path)
    end

    private

    def client
      @client ||= begin
        Aws::S3::Client.new(region: Settings.vba_documents.s3.region,
                            access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                            secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
      end
    end
  end
end
