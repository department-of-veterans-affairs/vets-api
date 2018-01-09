# frozen_string_literal: true

require 'common/models/base'
require 'pdf/reader'

class EVSSClaimDocument < Common::Base
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attribute :evss_claim_id, Integer
  attribute :tracked_item_id, Integer
  attribute :document_type, String
  attribute :file_name, String
  attribute :file_obj, ActionDispatch::Http::UploadedFile

  validates(:file_name, presence: true)
  validate :known_document_type?
  validate :unencrypted_pdf?
  before_validation :normalize_text

  # rubocop:disable LineLength
  DOCUMENT_TYPES = {
    'L029' => 'Copy of a DD214',
    'L450' => 'STR - Dental - Photocopy',
    'L451' => 'STR - Medical - Photocopy',
    'L049' => 'Medical Treatment Record - Non-Government Facility',
    'L034' => 'Military Personnel Record',
    'L107' => 'VA Form 21-4142 - Authorization To Disclose Information',
    'L827' => 'VA Form 21-4142a - General Release for Medical Provider Information',
    'L229' => 'VA Form 21-0781a - Statement in Support of Claim for PTSD Secondary to Personal Assault',
    'L228' => 'VA Form 21-0781 - Statement in Support of Claim for PTSD',
    'L149' => 'VA Form 21-8940 - Veterans Application for Increased Compensation Based on Un-employability',
    'L115' => 'VA Form 21-4192 - Request for Employment Information in Connection with Claim for Disability',
    'L159' => 'VA Form 26-4555 - Application in Acquiring Specially Adapted Housing or Special Home Adaptation Grant',
    'L117' => 'VA Form 21-4502 - Application for Automobile or Other Conveyance and Adaptive Equipment Under 38 U.S.C. 3901-3904',
    'L139' => 'VA Form 21-686c - Declaration of Status of Dependents',
    'L133' => 'VA Form 21-674 - Request for Approval of School Attendance',
    'L102' => 'VA Form 21-2680 - Examination for Housebound Status or Permanent Need for Regular Aid & Attendance',
    'L222' => 'VA Form 21-0779 - Request for Nursing Home Information in Connection with Claim for Aid & Attendance',
    'L702' => 'Disability Benefits Questionnaire (DBQ)',
    'L703' => 'Goldmann Perimetry Chart/Field Of Vision Chart',
    'L070' => 'Photographs',
    'L023' => 'Other Correspondence'
  }.freeze
  # rubocop:enable LineLength

  EVSS_TEXT_ENCODING = 'ascii' # EVSS only accepts text files written in ASCII
  MINIMUM_ENCODING_CONFIDENCE = 0.5

  def description
    DOCUMENT_TYPES[document_type]
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
    return unless file_name =~ /\.pdf$/i
    xref = PDF::Reader::XRef.new file_obj.tempfile
    errors.add(:base, 'PDF must not be encrypted') if xref.trailer[:Encrypt].present?
    file_obj.tempfile.rewind
  rescue PDF::Reader::MalformedPDFError
    errors.add(:base, 'PDF is malformed')
  end

  def normalize_text
    return unless file_name =~ /\.txt$/i
    text = file_obj.read
    text = text.encode(EVSS_TEXT_ENCODING)
    file_obj.tempfile = Tempfile.new(encoding: EVSS_TEXT_ENCODING)
    file_obj.tempfile.write text
    file_obj.tempfile.rewind
  rescue Encoding::UndefinedConversionError
    errors.add(:base, 'Cannot read file encoding. Text files must be ASCII encoded.')
    false
  end
end
