# frozen_string_literal: true

require 'vets/model'
require 'pdf_info'
require 'common/pdf_helpers'

class LighthouseDocument
  include Vets::Model
  include ActiveModel::Validations::Callbacks
  include Vets::SharedLogging

  attribute :first_name, String
  attribute :claim_id, Integer
  attribute :document_type, String
  attribute :file_name, String
  attribute :file_extension, String
  attribute :file_obj, ActionDispatch::Http::UploadedFile
  attribute :participant_id, String
  attribute :password, String
  attribute :tracked_item_id, Integer
  attribute :uuid, String

  validates(:file_name, presence: true)
  validates(:participant_id, presence: true)
  validate :known_document_type?
  validate :unencrypted_pdf?
  # Taken from LighthouseDocumentUploaderBase
  validates(:file_extension, inclusion: { in: %w[pdf gif png tiff tif jpeg jpg bmp txt] })
  before_validation :set_file_extension, :normalize_text, :convert_to_unlocked_pdf, :normalize_file_name

  # rubocop:disable Layout/LineLength
  DOCUMENT_TYPES = {
    '1489' => 'Hypertension Rapid Ready For Decision Summary PDF',
    'L014' => 'Birth Certificate',
    'L015' => 'Buddy/Lay Statement',
    'L018' => 'Civilian Police Reports',
    'L023' => 'Other Correspondence',
    'L029' => 'Copy of a DD214',
    'L033' => 'Death Certificate',
    'L034' => 'Military Personnel Record',
    'L037' => 'Divorce Decree',
    'L048' => 'Medical Treatment Record - Government Facility',
    'L049' => 'Medical Treatment Record - Non-Government Facility',
    'L051' => 'Marriage Certificate',
    'L070' => 'Photographs',
    'L102' => 'VA Form 21-2680 - Examination for Housebound Status or Permanent Need for Regular Aid & Attendance',
    'L107' => 'VA Form 21-4142 - Authorization To Disclose Information',
    'L115' => 'VA Form 21-4192 - Request for Employment Information in Connection with Claim for Disability',
    'L117' => 'VA Form 21-4502 - Application for Automobile or Other Conveyance and Adaptive Equipment Under 38 U.S.C. 3901-3904',
    'L133' => 'VA Form 21-674 - Request for Approval of School Attendance',
    'L139' => 'VA Form 21-686c - Declaration of Status of Dependents',
    'L149' => 'VA Form 21-8940 - Veterans Application for Increased Compensation Based on Un-employability',
    'L159' => 'VA Form 26-4555 - Application in Acquiring Specially Adapted Housing or Special Home Adaptation Grant',
    'L222' => 'VA Form 21-0779 - Request for Nursing Home Information in Connection with Claim for Aid & Attendance',
    'L228' => 'VA Form 21-0781 - Statement in Support of Claimed Mental Health Disorder(s) Due to an In-Service Traumatic Event(s)',
    'L229' => 'VA Form 21-0781a - Statement in Support of Claim for PTSD Secondary to Personal Assault',
    'L418' => 'Court papers / documents',
    'L450' => 'STR - Dental - Photocopy',
    'L451' => 'STR - Medical - Photocopy',
    'L478' => 'Medical Treatment Records - Furnished by SSA',
    'L702' => 'Disability Benefits Questionnaire (DBQ)',
    'L703' => 'Goldmann Perimetry Chart/Field Of Vision Chart',
    'L827' => 'VA Form 21-4142a - General Release for Medical Provider Information',
    'L1489' => 'Automated Review Summary Document'
  }.freeze
  # rubocop:enable Layout/LineLength

  LIGHTHOUSE_TEXT_ENCODING = 'ascii' # Lighthouse only accepts text files written in ASCII
  MINIMUM_ENCODING_CONFIDENCE = 0.5

  def description
    DOCUMENT_TYPES[document_type]
  end

  def uploader_ids
    [tracked_item_id, uuid]
  end

  def ==(other)
    attributes == other.attributes
  end

  def to_serializable_hash
    # file_obj is not suitable for serialization
    attributes.tap { |h| h.delete :file_obj }
  end

  # The front-end URL encodes a nil tracked_item_id as the string 'null'
  def tracked_item_id=(num)
    @tracked_item_id = num == 'null' ? nil : num
  end

  private

  def known_document_type?
    errors.add(:base, I18n.t('errors.messages.uploads.document_type_unknown')) unless description
  end

  def convert_to_unlocked_pdf
    return unless file_name.match?(/\.pdf$/i) && password.present?

    tempfile_without_pass = Tempfile.new(%w[decrypted_lighthouse_claim_document .pdf])
    unlock_succeeded = false

    begin
      # Choose PDF unlocking strategy
      if Flipper.enabled?(:lighthouse_document_convert_to_unlocked_pdf_use_hexapdf)
        unlock_with_hexapdf(tempfile_without_pass)
      else
        unlock_with_pdftk(tempfile_without_pass)
      end

      unlock_succeeded = true

      # Only swap files if unlock succeeded
      file_obj.tempfile.unlink
      file_obj.tempfile = tempfile_without_pass
    ensure
      cleanup_after_unlock(tempfile_without_pass, unlock_succeeded)
    end
  end

  def unlock_with_hexapdf(tempfile_without_pass)
    ::Common::PdfHelpers.unlock_pdf(file_obj.tempfile.path, password, tempfile_without_pass)
    tempfile_without_pass.rewind
  rescue Common::Exceptions::UnprocessableEntity => e
    log_pdf_unlock_error(e)
    errors.add(:base, I18n.t('errors.messages.uploads.pdf.incorrect_password'))
  end

  def unlock_with_pdftk(tempfile_without_pass)
    pdftk = PdfForms.new(Settings.binaries.pdftk)

    begin
      pdftk.call_pdftk(file_obj.tempfile.path,
                       'input_pw', password,
                       'output', tempfile_without_pass.path)
    rescue PdfForms::PdftkError => e
      handle_pdftk_error(e)
    end
  end

  def handle_pdftk_error(error)
    log_pdf_unlock_error(error)
    errors.add(:base, I18n.t('errors.messages.uploads.pdf.incorrect_password'))
  end

  def log_pdf_unlock_error(error)
    file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
    password_regex = /(input_pw).*?(output)/
    is_va_gov_service_error = error.respond_to?(:errors)
    message = is_va_gov_service_error ? error.errors&.first&.detail : error.message
    sanitized_message = message.gsub(file_regex, '[FILTERED FILENAME]')
                               .gsub(password_regex, '\1 [FILTERED] \2')
    error_source = is_va_gov_service_error ? error.errors&.first&.source : 'pdftk'
    sanitized_error = if is_va_gov_service_error
                        error.class.new({ detail: sanitized_message, source: error_source })
                      else
                        error.class.new(sanitized_message)
                      end
    sanitized_error.set_backtrace(error.backtrace)
    log_exception_to_rails(sanitized_error, :warn)
  end

  def cleanup_after_unlock(tempfile_without_pass, unlock_succeeded)
    # Always clear password from memory
    @password = nil

    # Clean up unused tempfile if unlock failed
    if tempfile_without_pass && !unlock_succeeded
      begin
        tempfile_without_pass.close
      rescue
        nil
      end
      begin
        tempfile_without_pass.unlink
      rescue
        nil
      end
    end
  end

  def unencrypted_pdf?
    return unless file_name.match?(/\.pdf$/i) && file_obj

    metadata = PdfInfo::Metadata.read(file_obj.tempfile)
    errors.add(:base, I18n.t('errors.messages.uploads.encrypted')) if metadata.encrypted?
    Rails.logger.info("Document for claim #{claim_id} is encrypted") if metadata.encrypted?
    file_obj.tempfile.rewind
  rescue PdfInfo::MetadataReadError => e
    log_exception_to_rails(e, :warn)
    Rails.logger.info("MetadataReadError: Document for claim #{claim_id}")
    if e.message.include?('Incorrect password')
      errors.add(:base, I18n.t('errors.messages.uploads.pdf.locked'))
    else
      errors.add(:base, I18n.t('errors.messages.uploads.malformed_pdf'))
    end
  end

  def set_file_extension
    self.file_extension = file_name.downcase.split('.').last
  end

  def normalize_text
    return unless file_name.match?(/\.txt$/i) && file_obj

    text = file_obj.read
    text = text.encode(LIGHTHOUSE_TEXT_ENCODING)
    file_obj.tempfile = Tempfile.new(encoding: LIGHTHOUSE_TEXT_ENCODING)
    file_obj.tempfile.write text
    file_obj.tempfile.rewind
  rescue Encoding::UndefinedConversionError
    errors.add(:base, I18n.t('errors.messages.uploads.ascii_encoded'))
  end

  def normalize_file_name
    return if !file_name || file_name.frozen?

    # remove all but the last "."  in the file name
    file_name.gsub!(/[.](?=.*[.])/, '')
  end
end
