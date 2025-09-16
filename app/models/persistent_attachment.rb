# frozen_string_literal: true

require 'common/convert_to_pdf'

# Persistent backing of a Shrine file upload, primarily used by SavedClaim
# at the moment.

# create_table "persistent_attachments", id: :serial, force: :cascade do |t|
#   t.uuid "guid"
#   t.string "type"
#   t.string "form_id"
#   t.datetime "created_at", null: false
#   t.datetime "updated_at", null: false
#   t.integer "saved_claim_id"
#   t.datetime "completed_at"
#   t.text "file_data_ciphertext"
#   t.text "encrypted_kms_key"
#   t.boolean "needs_kms_rotation", default: false, null: false
#   t.integer "doctype"
#   t.index ["guid"], name: "index_persistent_attachments_on_guid", unique: true
#   t.index ["id", "type"], name: "index_persistent_attachments_on_id_and_type"
#   t.index ["needs_kms_rotation"], name: "index_persistent_attachments_on_needs_kms_rotation"
#   t.index ["saved_claim_id"], name: "index_persistent_attachments_on_saved_claim_id"
# end
class PersistentAttachment < ApplicationRecord
  include SetGuid

  ALLOWED_DOCUMENT_TYPES = %w[.pdf .jpg .jpeg .png].freeze
  MINIMUM_FILE_SIZE = 1.kilobyte.freeze

  has_kms_key
  has_encrypted :file_data, key: :kms_key, **lockbox_options
  belongs_to :saved_claim, inverse_of: :persistent_attachments, optional: true
  delegate :original_filename, :size, to: :file

  def to_pdf
    Common::ConvertToPdf.new(file).run
  end

  # Returns the document type associated with the attachment.
  # Fallback to a default value of 10 - generic or unspecified document type.
  def document_type
    doctype || 10
  end

  # Determines whether stamped PDF validation is required for the attachment.
  # @see ClaimDocumentsController#create
  #
  # @return [Boolean] subclass should override to trigger validation
  def requires_stamped_pdf_validation?
    false
  end

  private

  def stamp_text
    I18n.l(saved_claim.created_at, format: :pdf_stamp)
  end
end
