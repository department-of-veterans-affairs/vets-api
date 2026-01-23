# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
class SupportingEvidenceAttachmentUploader < EVSSClaimDocumentUploaderBase
  before :store, :log_transaction_start
  after :store, :log_transaction_complete

  MAX_FILENAME_LENGTH = 100

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

  # Override filename to return a shortened version
  def filename
    return super if original_filename.nil?
    shorten_filename(original_filename)
  end

  # Override the :converted version to use shortened filenames
  version :converted, if: :tiff_or_incorrect_extension? do
    process(convert: :jpg, if: :tiff?)
    def full_filename(original_name_for_file)
      # Use the shortened filename for the converted version
      shortened_original = shorten_filename(original_name_for_file)
      name = "converted_#{shortened_original}"
      extension = CarrierWave::SanitizedFile.new(nil).send(:split_extension, original_name_for_file)[1]
      mimemagic_object = self.class.inspect_binary file
      if self.class.incorrect_extension?(extension:, mimemagic_object:)
        extension = self.class.extensions_from_mimemagic_object(mimemagic_object).max
        return "#{name.gsub('.', '_')}.#{extension}"
      end
      name
    end
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "disability_compensation_supporting_form/#{@guid}"
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

  def shorten_filename(filename)
    return filename if filename.length <= MAX_FILENAME_LENGTH

    # Preserve file extension while shortening
    extension = File.extname(filename)
    name_without_ext = File.basename(filename, extension)
    max_name_length = MAX_FILENAME_LENGTH - extension.length
    shortened_name = name_without_ext[0, max_name_length]
    shortened_name + extension
  end
end
