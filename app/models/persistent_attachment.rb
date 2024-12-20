# frozen_string_literal: true

require 'common/convert_to_pdf'

# Persistent backing of a Shrine file upload, primarily used by SavedClaim
# at the moment.

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

  private

  def stamp_text
    I18n.l(saved_claim.created_at, format: :pdf_stamp)
  end
end
