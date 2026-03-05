# frozen_string_literal: true

require 'common/file_helpers'
require 'common/virus_scan'
require 'digest'
require 'request_store'

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
    scan_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = Common::VirusScan.scan(temp_file_path)
    scan_duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - scan_start) * 1000).round
    File.delete(temp_file_path)

    log_scan_result(
      file:,
      scan_result: result ? 'clean' : 'virus_detected',
      virus_name: nil, # Will be populated when Common::VirusScan (#133914) returns virus_name
      scan_duration_ms:
    )

    # Common::VirusScan result will return true or false
    unless result # unless safe
      file.delete
      raise VirusFoundError, 'virus or malware detected'
    end
  end

  private

  def log_scan_result(file:, scan_result:, virus_name:, scan_duration_ms:)
    file_name_hash = Digest::SHA256.hexdigest(file.original_filename.to_s)
    upload_context = model&.class&.name || self.class.name

    log_level = scan_result == 'virus_detected' ? :warn : :info
    Rails.logger.public_send(log_level,
                             'ClamAV scan completed',
                             ip_address: RequestStore.store.dig('additional_request_attributes', 'remote_ip'),
                             file_name_hash:,
                             file_size: file.size,
                             content_type: file.content_type,
                             scan_result:,
                             virus_name:,
                             scan_duration_ms:,
                             upload_context:)
  end
end
