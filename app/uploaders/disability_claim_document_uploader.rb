# frozen_string_literal: true

class DisabilityClaimDocumentUploader < CarrierWave::Uploader::Base
  MAX_FILE_SIZE = 25.megabytes

  before :store, :validate_file_size

  def store_dir
    'disability_claim_documents'
  end

  def extension_white_list
    %w(pdf gif tiff tif jpeg jpg bmp txt)
  end

  def move_to_cache
    false
  end

  private

  def validate_file_size(file)
    raise CarrierWave::UploadError, 'File size larger than allowed' if file.size > MAX_FILE_SIZE
  end
end
