# frozen_string_literal: true

require 'attr_encrypted'

# Persistent backing of a Shrine file upload, primarily used by SavedClaim
# at the moment. Subclasses need to define a constant, `UPLOADER_CLASS`,
# which references a subclass of `FileUpload` and defines the `uploader`
# and `workflow` that determine how a file is stored and what actions it
# goes through when it's ready to be sent to a backend system.

# Current subclasses are PensionBurial

class PersistentAttachment < ActiveRecord::Base
  include SetGuid

  attr_encrypted(:file_data, key: Settings.db_encryption_key)
  belongs_to :saved_claim, inverse_of: :persistent_attachments
  delegate :original_filename, :size, to: :file

  def to_pdf
    PensionBurial::ConvertToPdf.new(file).run
  end

  private

  def stamp_text
    I18n.l(saved_claim.created_at, format: :pdf_stamp)
  end
end
