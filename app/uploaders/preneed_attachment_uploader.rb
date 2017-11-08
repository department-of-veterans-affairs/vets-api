# frozen_string_literal: true

class PreneedAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize

  MAX_FILE_SIZE = 25.megabytes
end
