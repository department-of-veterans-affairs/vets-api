# frozen_string_literal: true

require 'common/models/base'
require 'pdf_info'

class LighthouseDocument < Common::Base
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include SentryLogging

  attribute :file_number, String
  attribute :claim_id, Integer
  attribute :tracked_item_id, Integer
  attribute :document_type, String
  attribute :file_name, String
  attribute :uuid, String
  attribute :file_obj, ActionDispatch::Http::UploadedFile
  attribute :password, String

  validates(:file_name, presence: true)
  validates(:file_number, presence: true)
  validate :known_document_type?
  validate :unencrypted_pdf?
  before_validation :normalize_text, :convert_to_unlocked_pdf, :normalize_file_name

  # rubocop:disable Layout/LineLength
  DOCUMENT_TYPES = {
    '1489' => 'Hypertension Rapid Ready For Decision Summary PDF',
    'L015' => 'Buddy/Lay Statement',
    'L018' => 'Civilian Police Reports',
    'L023' => 'Other Correspondence',
    'L029' => 'Copy of a DD214',
    'L034' => 'Military Personnel Record',
    'L048' => 'Medical Treatment Record - Government Facility',
    'L049' => 'Medical Treatment Record - Non-Government Facility',
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
    'L228' => 'VA Form 21-0781 - Statement in Support of Claim for PTSD',
    'L229' => 'VA Form 21-0781a - Statement in Support of Claim for PTSD Secondary to Personal Assault',
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
    to_hash.tap { |h| h.delete :file_obj }
  end

  # The front-end URLencodes a nil tracked_item_id as the string 'null'
  def tracked_item_id=(num)
    num = nil if num == 'null'
    super num
  end

  private

  def known_document_type?
    errors.add(:base, I18n.t('errors.messages.uploads.document_type_unknown')) unless description
  end

  def convert_to_unlocked_pdf
    return unless file_name.match?(/\.pdf$/i) && password.present?

    pdftk = PdfForms.new(Settings.binaries.pdftk)
    tempfile_without_pass = Tempfile.new(['decrypted_lighthouse_claim_document', '.pdf'])

    error_messages = pdftk.call_pdftk(file_obj.tempfile.path,
                                      'input_pw', password,
                                      'output', tempfile_without_pass.path)
    if error_messages.present? && error_messages.include?('Error')
      log_message_to_sentry(error_messages, 'warn')
      errors.add(:base, I18n.t('errors.messages.uploads.pdf.incorrect_password'))
    end

    @password = nil

    file_obj.tempfile.unlink
    file_obj.tempfile = tempfile_without_pass
  end

  def unencrypted_pdf?
    return unless file_name.match?(/\.pdf$/i) && file_obj

    metadata = PdfInfo::Metadata.read(file_obj.tempfile)
    errors.add(:base, I18n.t('errors.messages.uploads.encrypted')) if metadata.encrypted?
    file_obj.tempfile.rewind
  rescue PdfInfo::MetadataReadError => e
    log_exception_to_sentry(e, nil, nil, 'warn')
    if e.message.include?('Incorrect password')
      errors.add(:base, I18n.t('errors.messages.uploads.pdf.locked'))
    else
      errors.add(:base, I18n.t('errors.messages.uploads.malformed_pdf'))
    end
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
