# frozen_string_literal: true

require 'common/models/base'

class EVSSClaimDocument < Common::Base
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attribute :evss_claim_id, Integer
  attribute :tracked_item_id, Integer
  attribute :document_type, String
  attribute :file_name, String
  attribute :uuid, String
  attribute :file_obj, ActionDispatch::Http::UploadedFile

  validates(:file_name, presence: true)
  validate :known_document_type?
  validate :unencrypted_pdf?
  before_validation :normalize_text

  # rubocop:disable Layout/LineLength
  DOCUMENT_TYPES = {
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
    'L827' => 'VA Form 21-4142a - General Release for Medical Provider Information'
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

  def known_document_type?
    errors.add(:base, 'Must use a known document type') unless description
  end

  def unencrypted_pdf?
    return unless file_name.match?(/\.pdf$/i)

    metadata = PdfInfo::Metadata.read(file_obj.tempfile)
    errors.add(:base, 'PDF must not be encrypted') if metadata.encrypted?
    file_obj.tempfile.rewind
  rescue PdfInfo::MetadataReadError
    errors.add(:base, 'PDF is malformed')
  end

  def normalize_text
    return unless file_name.match?(/\.txt$/i)

    text = file_obj.read
    text = text.encode(EVSS_TEXT_ENCODING)
    file_obj.tempfile = Tempfile.new(encoding: EVSS_TEXT_ENCODING)
    file_obj.tempfile.write text
    file_obj.tempfile.rewind
  rescue Encoding::UndefinedConversionError
    errors.add(:base, 'Cannot read file encoding. Text files must be ASCII encoded.')
  end
end
