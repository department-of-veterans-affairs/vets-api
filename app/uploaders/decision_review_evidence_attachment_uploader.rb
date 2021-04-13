# frozen_string_literal: true

# Files uploaded as part of a Notice of Disagreement submission that will be sent to Lighthouse upon form submission.
class DecisionReviewEvidenceAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig

  def size_range
    1.byte...100.megabytes
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
    #  defaults to CarrierWave::Storage::File if not AWS
    if Rails.env.production?
      s3_settings = Settings.lighthouse.decision_reviews.s3
      set_aws_config(
        s3_settings.aws_access_key_id,
        s3_settings.aws_secret_access_key,
        s3_settings.region,
        s3_settings.bucket
      )
    end
  end
end
