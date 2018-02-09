module UploaderVirusScan
  extend ActiveSupport::Concern

  class VirusFoundError < StandardError
  end

  included do
    before(:store, :validate_virus_free)
  end

  def validate_virus_free(file)
    return unless Rails.env.production?
    result = Common::VirusScan.scan(file.tempfile.path)

    unless result.safe?
      raise VirusFoundError, result.body
    end
  end
end
