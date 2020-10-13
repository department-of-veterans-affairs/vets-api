# frozen_string_literal: true

require 'origami'

module ValidatePdf
  extend ActiveSupport::Concern

  included do
    before :store, :validate_pdf
  end

  def convert_to_temp_file(file)
    temp_file = file.tempfile
    return unless File.extname(temp_file) == '.pdf'

    temp_file
  end

  def validate(temp_file)
    pdf = Origami::PDF.read temp_file, decrypt: false
    if pdf.encrypted?
      raise Common::Exceptions::UnprocessableEntity.new(detail: I18n.t('errors.messages.uploads.pdf.locked'),
                                                        source: 'ValidatePdf')
    end
  rescue Origami::InvalidPDFError
    raise Common::Exceptions::UnprocessableEntity.new(detail: I18n.t('errors.messages.uploads.pdf.invalid'),
                                                      source: 'ValidatePdf')
  end

  def validate_pdf(file)
    temp_file = convert_to_temp_file file
    validate temp_file unless temp_file.nil?
  end
end
