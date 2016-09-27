# frozen_string_literal: true

class DisabilityClaimDocumentUploader < CarrierWave::Uploader::Base
  # This method is modified in testing so not possible to get test coverage
  # :nocov:
  def store_dir
    'disability_claim_documents'
  end
  # :nocov:

  def extension_white_list
    %w(pdf gif tiff tif jpeg jpg bmp txt)
  end

  def move_to_cache
    false
  end
end
