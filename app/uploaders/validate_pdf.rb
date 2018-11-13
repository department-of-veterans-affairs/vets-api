# frozen_string_literal: true

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def validate_pdf(file)
    return unless file.readpartial(4) == '%PDF'
    file.seek(-7, IO::SEEK_END)
    raise CarrierWave::UploadError, 'PDF is missing an end of file marker' unless file.read.include?('%%EOF')
    PDF::Reader.new(file).info
  rescue PDF::Reader::EncryptedPDFError
    raise CarrierWave::UploadError, 'PDF is encrypted'
  end
end
