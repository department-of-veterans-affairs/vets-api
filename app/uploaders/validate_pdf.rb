# frozen_string_literal: true

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def validate_pdf(file)
    temp_file = file.tempfile
    return unless temp_file.readpartial(4) == '%PDF'

    PDF::Reader.new(temp_file).info
  rescue PDF::Reader::MalformedPDFError
    raise CarrierWave::UploadError, 'PDF is missing an end of file marker'
  rescue PDF::Reader::EncryptedPDFError
    raise CarrierWave::UploadError, 'PDF is encrypted'
  end
end
