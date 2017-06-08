# frozen_string_literal: true
require 'shrine/plugins/validate_unlocked_pdf'
require 'shrine/plugins/validate_ascii'

class EVSS::Uploader < Shrine
  plugin :validation_helpers
  plugin :validate_unlocked_pdf
  plugin :validate_ascii

  Attacher.validate do
    validate_max_size 25.megabytes
    # validate_min_size 1.kilobyte
    validate_mime_type_inclusion %w(
      image/jpeg image/png image/bmp image/tif image/tiff
      application/pdf
      text/plain application/octet-stream
    )
    validate_unlocked_pdf if get.mime_type == 'application/pdf'
    validate_ascii if get.original_filename.ends_with?('.txt')
  end

  def generate_location(_io, context)
    filename = context[:metadata]['filename']
    record = context[:record]
    segments = ['evss_claim_documents', record.user_uuid, record.document[:tracked_item_id], filename]
    File.join(segments.compact.map(&:to_s))
  end
end
