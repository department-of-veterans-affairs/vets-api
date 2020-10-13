# frozen_string_literal: true

require 'pdf_info'

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def validate(temp_file)
    metadata = PdfInfo::Metadata.read(temp_file)
    if metadata.encrypted?
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'The uploaded PDF file is encrypted and cannot be read',
                                                        source: 'ValidatePdf')
    end
    temp_file.rewind
  rescue PdfInfo::MetadataReadError
    raise Common::Exceptions::UnprocessableEntity.new(detail: 'The uploaded PDF file is invalid and cannot be read',
                                                      source: 'ValidatePdf')
  end

  def validate_pdf(file)
    temp_file = file.tempfile
    return unless File.extname(temp_file) == '.pdf' && !temp_file.nil?

    validate temp_file
  end
end
