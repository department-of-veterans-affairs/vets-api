# frozen_string_literal: true

require 'common/file_helpers'
require 'common/virus_scan'

module UploaderVirusScan
  extend ActiveSupport::Concern

  class VirusFoundError < StandardError
  end

  included do
    before(:store, :validate_virus_free)
  end

  def validate_virus_free(file)
    return unless Rails.env.production?

    temp_file_path = Common::FileHelpers.generate_clamav_temp_file(file.read)
    upload_context = model&.class&.name || self.class.name
    result = Common::VirusScan.scan(temp_file_path, upload_context:)
    File.delete(temp_file_path)

    # Common::VirusScan emits AU-2 audit log and returns true/false
    unless result # unless safe
      file.delete
      raise VirusFoundError, 'virus or malware detected'
    end
  end
end
