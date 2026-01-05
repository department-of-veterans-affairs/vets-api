# frozen_string_literal: true

require 'clamav/commands/patch_scan_command'
require 'clamav/patch_client'
require 'fileutils'

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      raise 'Failed to create temp file' unless File.exist?(file_path)

      return true if mock_enabled?

      if file_path.start_with?('clamav_tmp/')
        Rails.logger.info('Scanning file already in clamav_tmp')
        File.chmod(0o640, file_path)
        ClamAV::PatchClient.new.safe?(file_path)
      elsif Flipper.enabled?(:clamav_scan_file_from_other_location)
        # File is elsewhere (e.g., tmp/pdfs/), copy to clamav_tmp for scanning
        Rails.logger.info("Creating clamav tmp file for: #{file_path}")
        scan_file_from_other_location(file_path)
      else
        Rails.logger.warn("Clamav scan from other location disabled for: #{file_path}")
        false
      end
    end

    def scan_file_from_other_location(original_path)
      # Create clamav_tmp directory if it doesn't exist
      clamav_directory = Rails.root.join('clamav_tmp')
      FileUtils.mkdir_p(clamav_directory)

      File.chmod(0o640, original_path)

      # Generate unique filename to avoid collisions
      unique_id = "scan_#{Time.now.to_i}_#{SecureRandom.hex(8)}"
      temp_filename = "#{unique_id}_#{File.basename(original_path)}"
      temp_path = "clamav_tmp/#{temp_filename}"

      begin
        # Copy file to clamav_tmp
        FileUtils.cp(original_path, temp_path)

        raise "Failed to create temp file at #{original_path}" unless File.exist?(temp_path)

        Rails.logger.info("Created clamav tmp file: #{original_path}")

        File.chmod(0o640, temp_path)
        scan_result = ClamAV::PatchClient.new.safe?(temp_path)
        scan_result
      ensure
        # Always clean up the temporary copy
        delete_file_if_exists(temp_path)
      end
    rescue => e
      Rails.logger.error("VirusScan failed for #{original_path}: #{e.message}")
      # Ensure cleanup happens even on error
      delete_file_if_exists(temp_path) if defined?(temp_path)
      raise
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
