# frozen_string_literal: true

# Files uploaded as part of a Notice of Disagreement submission that will be sent to Lighthouse upon form submission.
class DecisionReviewEvidenceAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig

  def size_range
    (1.byte)...(100_000_000.bytes)
  end

  def extension_allowlist
    %w[pdf]
  end

  def initialize(decision_review_guid)
    super
    @decision_review_guid = decision_review_guid

    set_storage_options!
  end

  def store_dir
    raise 'missing guid' if @decision_review_guid.blank?

    "decision_review/#{@decision_review_guid}"
  end

  def set_storage_options!
    s3_settings = Settings.decision_review.s3
    #  defaults to CarrierWave::Storage::File if not AWS unless a real aws_access_key_id is set
    if s3_settings.aws_access_key_id.present?
      set_aws_config(
        s3_settings.aws_access_key_id,
        s3_settings.aws_secret_access_key,
        s3_settings.region,
        s3_settings.bucket
      )
    end
  end
end
