# frozen_string_literal: true
module ValidateFileSize
  extend ActiveSupport::Concern

  included do
    before :store, :validate_file_size
  end

  def validate_file_size(file)
    raise CarrierWave::UploadError, 'File size larger than allowed' if file.size > self.class::MAX_FILE_SIZE
  end
end
