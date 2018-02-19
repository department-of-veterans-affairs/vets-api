# frozen_string_literal: true

module UploaderVirusScan
  extend ActiveSupport::Concern

  class VirusFoundError < StandardError
  end

  included do
    before(:store, :validate_virus_free)
  end

  def validate_virus_free(file)
    return unless Rails.env.production?
    temp_file_path = Common::FileHelpers.generate_temp_file(file.read)
    result = Common::VirusScan.scan(temp_file_path)
    File.delete(temp_file_path)

    unless result.safe?
      file.delete
      raise VirusFoundError, result.body
    end
  end
end
