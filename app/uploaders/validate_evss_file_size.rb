# frozen_string_literal: true

module ValidateEvssFileSize
  extend ActiveSupport::Concern

  included do
    before :store, :validate_file_size
  end

  def max_file_size_non_pdf
    50.megabytes
  end

  # EVSS will split PDF's larger than 50mb before sending to VBA who has a limit of 50mb. so,
  # PDF's can be larger than other files
  def validate_file_size(file)
    if file.content_type != 'application/pdf' && file.size > max_file_size_non_pdf
      raise CarrierWave::IntegrityError, I18n.translate(:"errors.messages.max_size_error",
                                                        max_size: '50MB')
    end
  end
end
