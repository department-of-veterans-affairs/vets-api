# frozen_string_literal: true

require 'shrine/plugins/validate_unlocked_pdf'
require 'shrine/plugins/validate_pdf_page_count'
require 'shrine/plugins/validate_correct_form'

class FormUpload::Uploader < VetsShrine
  plugin :storage_from_config, settings: Settings.shrine.claims
  plugin :activerecord, callbacks: false
  plugin :validate_unlocked_pdf
  plugin :store_dimensions
  plugin :validate_pdf_page_count
  plugin :validate_correct_form

  Attacher.validate do
    validate_virus_free
    validate_max_size 25.megabytes
    validate_min_size 1.kilobyte
    validate_mime_type_inclusion %w[image/jpg image/jpeg image/png application/pdf]
    validate_max_width 5000 if get.width
    validate_max_height 10_000 if get.height
    validate_unlocked_pdf
    validate_pdf_page_count(max_pages: record.max_pages, min_pages: record.min_pages)
    validate_correct_form(form_id: record.form_id)
  end
end
