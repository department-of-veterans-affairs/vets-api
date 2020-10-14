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
      raise Common::Exceptions::UnprocessableEntity.new(detail: I18n.t('errors.messages.uploads.pdf.locked'),
                                                        source: 'ValidatePdf')
    end
    temp_file.rewind
  rescue PdfInfo::MetadataReadError
    raise Common::Exceptions::UnprocessableEntity.new(detail: I18n.t('errors.messages.uploads.pdf.invalid'),
                                                      source: 'ValidatePdf')
  end

  def validate_pdf(file)
    temp_file = file.tempfile
    return unless File.extname(temp_file) == '.pdf' && !temp_file.nil?

    validate temp_file
  end
end
