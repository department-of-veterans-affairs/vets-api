# frozen_string_literal: true

require 'origami'

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def convert_to_temp_file(file)
    temp_file = file.tempfile
    return unless temp_file.readpartial(4) == '%PDF'
    temp_file
  end

  def validate(temp_file)
    pdf = Origami::PDF.read temp_file, decrypt: false
    raise CarrierWave::UploadError, 'The uploaded PDF file is encrypted and cannot be read. Please upload unencrypted PDF files only.' if pdf.encrypted?
  rescue Origami::InvalidPDFError
    raise CarrierWave::UploadError, 'The uploaded PDF file is invalid and cannot be read.'
  end

  def validate_pdf(file)
    temp_file = convert_to_temp_file file
    validate temp_file unless temp_file.nil?
  end
end
