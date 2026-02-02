# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
class SupportingEvidenceAttachmentUploader < EVSSClaimDocumentUploaderBase
  # Maximum filename length to avoid filesystem errors (ENAMETOOLONG)
  # Linux/macOS typically allow 255 chars, but CarrierWave temp files append suffixes.
  # CarrierWave's temp filenames (e.g., during retrieve_from_store!) add a timestamp and random
  # component to the original filename (roughly 25–35 extra characters such as
  # "_20240101-1234-1a2b3c4d5e"). Limiting the base filename to 100 characters keeps the final
  # temp path well under common 255-character filesystem limits, even if the pattern changes slightly.
  MAX_FILENAME_LENGTH = 100

  before :store, :log_transaction_start
  after :store, :log_transaction_complete

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

  # Override CarrierWave's filename method to shorten long filenames
  # This ensures the stored filename is short enough to avoid ENAMETOOLONG errors
  # when CarrierWave later creates temp files during retrieve_from_store!
  def filename
    base_filename = super
    return base_filename if base_filename.nil?

    shorten_filename(base_filename)
  end

  def log_transaction_start(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      upload_start: Time.current
    }

    Rails.logger.info(log)
  end

  def log_transaction_complete(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      upload_complete: Time.current
    }

    Rails.logger.info(log)
  end

  private

  # Shortens a filename to MAX_FILENAME_LENGTH while preserving the extension
  def shorten_filename(filename)
    return filename if filename.length <= MAX_FILENAME_LENGTH

    extension = File.extname(filename)
    basename = File.basename(filename, extension)
    max_basename_length = MAX_FILENAME_LENGTH - extension.length

    "#{basename[0, max_basename_length]}#{extension}"
  end
end
