# frozen_string_literal: true

module ValidateFileSize
  extend ActiveSupport::Concern

  included do
    before :store, :validate_file_size
  end

  def validate_file_size(file)
    if file.size > self.class.max_file_size
      raise Common::Exceptions::PayloadTooLarge.new(
        detail: 'File size larger than allowed',
        source: 'ValidateFileSize'
      )
    end
  end
end
