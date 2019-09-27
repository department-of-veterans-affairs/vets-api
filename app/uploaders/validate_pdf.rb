# frozen_string_literal: true

require 'origami'

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def validate_pdf(file)
    temp_file = file.tempfile
    return unless temp_file.readpartial(4) == '%PDF'

    pdf = Origami::PDF.read temp_file, decrypt: false
    raise CarrierWave::UploadError, 'PDF is encrypted' if pdf.encrypted?
  rescue Origami::InvalidPDFError
    raise CarrierWave::UploadError, 'PDF is invalid'
  end
end
