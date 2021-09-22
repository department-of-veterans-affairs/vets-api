# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
class SupportingEvidenceAttachmentUploader < EVSSClaimDocumentUploaderBase
  def initialize(guid, _unused = nil)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again
    # so the _unused argument is necessary

    super
    @guid = guid

    #  defaults to CarrierWave::Storage::File if not AWS
    if Rails.env.production?
      set_aws_config(
        Settings.evss.s3.aws_access_key_id,
        Settings.evss.s3.aws_secret_access_key,
        Settings.evss.s3.region,
        Settings.evss.s3.bucket
      )
    end
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "disability_compensation_supporting_form/#{@guid}"
  end
end
