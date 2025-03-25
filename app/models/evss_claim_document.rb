# frozen_string_literal: true

require 'common/models/base'
require 'pdf_info'

class EVSSClaimDocument < Common::Base
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include SentryLogging

  attribute :evss_claim_id, Integer
  attribute :tracked_item_id, Integer
  attribute :document_type, String
  attribute :file_name, String
  attribute :uuid, String
  attribute :file_obj, ActionDispatch::Http::UploadedFile
  attribute :password, String

  validates(:file_name, presence: true)
  validate :known_document_type?
  validate :content_type_matches_extension?
  validate :unencrypted_pdf?
  before_validation :normalize_text, :convert_to_unlocked_pdf, :normalize_file_name

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

  EVSS_TEXT_ENCODING = 'ascii' # EVSS only accepts text files written in ASCII
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

  def content_type_matches_extension?
    return unless file_obj

    true_mime_type = MimeMagic.by_magic(File.open(file_obj.tempfile.path)).to_s

    # MimeMagic cannot always determine the mime_type and will sometimes
    # return ''. In those cases it makes sense to fall back to the content_type
    # as passed in when the request is made
    true_mime_type = file_obj.content_type if true_mime_type.empty?

    assumed_mime_type = MimeMagic.by_extension(extension).to_s

    errors.add(:base, I18n.t('errors.messages.uploads.content_type_mismatch')) if true_mime_type != assumed_mime_type
  end

  def extension
    # Using file_name instead of file_path because the temp path doesn't include
    # an extension
    File.extname(file_name).downcase[1..] # Remove the leading dot
  end

  def known_document_type?
    errors.add(:base, I18n.t('errors.messages.uploads.document_type_unknown')) unless description
  end

  def convert_to_unlocked_pdf
    return unless file_name.match?(/\.pdf$/i) && password.present?

    pdftk = PdfForms.new(Settings.binaries.pdftk)
    tempfile_without_pass = Tempfile.new(['decrypted_evss_claim_document', '.pdf'])

    begin
      pdftk.call_pdftk(file_obj.tempfile.path,
                       'input_pw', password,
                       'output', tempfile_without_pass.path)
    rescue PdfForms::PdftkError => e
      file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
      password_regex = /(input_pw).*?(output)/
      sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
      log_message_to_sentry(sanitized_message, 'warn')
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
    text = text.encode(EVSS_TEXT_ENCODING)
    file_obj.tempfile = Tempfile.new(encoding: EVSS_TEXT_ENCODING)
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
