# frozen_string_literal: true
require 'shrine/plugins/validate_unlocked_pdf'
class ClaimDocumentation::Uploader < VetsShrine
  plugin :storage_from_config, settings: Settings.shrine.claims
  plugin :activerecord, callbacks: false
  plugin :validate_unlocked_pdf

  Attacher.validate do
    validate_virus_free
    validate_max_size 20.megabytes
    validate_min_size 1.kilobytes
    validate_mime_type_inclusion %w(image/jpg image/jpeg image/png application/pdf)
    validate_unlocked_pdf
  end

  def generate_location(io, context)
    # Because there are multiple entry paths for io objects
    # to get into Shrine, we need to handle each of them in
    # order to extract a base filename
    fname =
      case io
      when File
        File.basename(io.path)
      when ActionDispatch::Http::UploadedFile
        io.original_filename
      when Shrine::UploadedFile
        context[:metadata]['filename']
      end
    step = begin
             context[:record].current_task
           rescue
             'initialupload'
           end
    File.join(context[:record].form_id, context[:record].guid, [step, fname].join('-'))
  end
end
