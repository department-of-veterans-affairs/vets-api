# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    belongs_to :supportable, polymorphic: true

    attr_encrypted(:file_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    def get_location
      rewrite_url(signed_url(id))
    end

    private

    def rewrite_url(url)
      rewritten = url.sub!(Settings.modules_appeals_api.evidence_submissions.location.prefix,
                           Settings.modules_appeals_api.evidence_submissions.location.replacement)
      raise 'Unable to provide document upload location' unless rewritten

      rewritten
    end

    def signed_url(id)
      s3 = Aws::S3::Resource.new(region: Settings.modules_appeals_api.s3.region,
                                 access_key_id: Settings.modules_appeals_api.s3.aws_access_key_id,
                                 secret_access_key: Settings.modules_appeals_api.s3.aws_secret_access_key)
      obj = s3.bucket(Settings.modules_appeals_api.s3.bucket).object(id)
      obj.presigned_url(:put, {})
    end
  end
end
