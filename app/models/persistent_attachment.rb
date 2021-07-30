# frozen_string_literal: true

require 'attr_encrypted'
require 'database/key_rotation'
require 'common/convert_to_pdf'

# Persistent backing of a Shrine file upload, primarily used by SavedClaim
# at the moment. Current subclasses are PensionBurial

class PersistentAttachment < ApplicationRecord
  include Database::KeyRotation
  include SetGuid

  attr_encrypted(:file_data, key: Proc.new { |r| r.encryption_key(:file_data) })
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
