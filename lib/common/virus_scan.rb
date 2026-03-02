# frozen_string_literal: true

require 'clamav/commands/patch_scan_command'
require 'clamav/patch_client'
require 'fileutils'
require 'marcel'

module Common
  module VirusScan
    module_function

    def scan(file_path, upload_context: nil)
      raise 'Failed to create temp file' unless File.exist?(file_path)
      return true if mock_enabled?

      file_metadata = collect_file_metadata(file_path)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = perform_scan(file_path)

      emit_scan_audit_log(
        file_metadata:, scan_result: result[:safe] ? 'clean' : 'infected',
        virus_name: result[:virus_name], scan_duration_ms: duration_ms(start_time), upload_context:
      )
      result[:safe]
    rescue
      emit_error_audit_log(file_metadata, start_time, upload_context) if start_time
      raise
    end

    def perform_scan(file_path)
      if file_path.start_with?('clamav_tmp/')
        Rails.logger.info('Scanning file already in clamav_tmp')
        File.chmod(0o640, file_path)
        ClamAV::PatchClient.new.scan_with_result(file_path)
      elsif Flipper.enabled?(:clamav_scan_file_from_other_location)
        Rails.logger.info("Creating clamav tmp file for: #{file_path}")
        scan_file_from_other_location(file_path)
      else
        Rails.logger.warn("Clamav scan from other location disabled for: #{file_path}")
        { safe: false, virus_name: nil }
      end
    end

    def scan_file_from_other_location(original_path)
      clamav_directory = Rails.root.join('clamav_tmp')
      FileUtils.mkdir_p(clamav_directory)
      File.chmod(0o640, original_path)

      temp_path = "clamav_tmp/scan_#{Time.now.to_i}_#{SecureRandom.hex(8)}_#{File.basename(original_path)}"

      begin
        FileUtils.cp(original_path, temp_path)
        raise "Failed to create temp file at #{original_path}" unless File.exist?(temp_path)

        Rails.logger.info("Created clamav tmp file: #{original_path}")
        File.chmod(0o640, temp_path)
        ClamAV::PatchClient.new.scan_with_result(temp_path)
      ensure
        delete_file_if_exists(temp_path)
      end
    rescue => e
      Rails.logger.error("VirusScan failed for #{original_path}: #{e.message}")
      delete_file_if_exists(temp_path) if defined?(temp_path)
      raise
    end

    def collect_file_metadata(file_path)
      {
        file_name_hashed: Digest::SHA256.hexdigest(File.basename(file_path)),
        file_size: File.size(file_path),
        content_type: Marcel::MimeType.for(Pathname.new(file_path))
      }
    rescue => e
      Rails.logger.warn("Failed to collect file metadata for scan audit: #{e.message}")
      { file_name_hashed: nil, file_size: nil, content_type: nil }
    end

    def emit_scan_audit_log(file_metadata:, scan_result:, virus_name:, scan_duration_ms:, upload_context:)
      request_attributes = RequestStore.store['additional_request_attributes'] || {}
      Rails.logger.info('ClamAV Virus Scan Audit',
                        event: 'virus_scan', user_uuid: request_attributes['user_uuid'],
                        ip_address: request_attributes['remote_ip'], file_name: file_metadata[:file_name_hashed],
                        file_size: file_metadata[:file_size], content_type: file_metadata[:content_type],
                        scan_result:, virus_name:, scan_duration_ms:, upload_context:)
    end

    def emit_error_audit_log(file_metadata, start_time, upload_context)
      emit_scan_audit_log(
        file_metadata: file_metadata || {}, scan_result: 'error',
        virus_name: nil, scan_duration_ms: duration_ms(start_time), upload_context:
      )
    end

    def duration_ms(start_time)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    end

    def delete_file_if_exists(file_path)
      return unless file_path && File.exist?(file_path)

      File.delete(file_path)
      Rails.logger.info("Deleted temp scan file: #{file_path}")
    rescue => e
      Rails.logger.warn("Failed to delete temp file #{file_path}: #{e.message}")
    end

    def mock_enabled?
      Settings.clamav.mock
    end
  end
end
