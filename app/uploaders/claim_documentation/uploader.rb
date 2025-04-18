# frozen_string_literal: true

require 'shrine/plugins/validate_unlocked_pdf'

# Shrine logic for Pension/Burial uploads, optimistically named so
# that they cover any sort of claim documentation in a sane way.

class ClaimDocumentation::Uploader < VetsShrine
  plugin :storage_from_config, settings: Settings.shrine.claims
  plugin :activerecord, callbacks: false
  plugin :validate_unlocked_pdf
  plugin :store_dimensions

  Attacher.validate do
    validate_virus_free
    validate_max_size 100.megabytes
    validate_min_size 1.kilobyte
    validate_mime_type_inclusion %w[image/jpg image/jpeg image/png application/pdf]
    validate_max_width 5000 if get.width
    validate_max_height 10_000 if get.height
    validate_unlocked_pdf
  end
end
