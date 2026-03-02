# frozen_string_literal: true

require 'common/virus_scan'
require 'datadog'
require 'digest'
require 'request_store'

class Shrine
  module Plugins
    module ValidateVirusFree
      module AttacherMethods
        def validate_virus_free(message: nil)
          Datadog::Tracing.trace('Scan Upload for Viruses') do
            file_to_scan = get.download
            temp_file_path = Common::FileHelpers.generate_clamav_temp_file(file_to_scan)
            result = Common::VirusScan.scan(temp_file_path)
            File.delete(temp_file_path)

            unless result
              log_virus_detected(temp_file_path)
              return add_error_msg(message || 'virus or malware detected')
            end

            true
          end
        end

        private

        def log_virus_detected(file_path)
          Rails.logger.warn(
            'Virus or malware detected during upload scan',
            scan_result: 'virus_detected',
            remote_ip: RequestStore.store.dig('additional_request_attributes', 'remote_ip'),
            file_name_hash: Digest::SHA256.hexdigest(File.basename(file_path)),
            upload_context: record&.class&.name
          )
        end

        def add_error_msg(message)
          if Rails.env.development? && message.match(/nodename nor servname provided/)
            Rails.logger.error('VIRUS SCANNING IS OFF. PLEASE START CLAMD')
            true
          else
            errors << (message || 'virus or malware detected')
            false
          end
        end
      end
    end

    register_plugin(:validate_virus_free, ValidateVirusFree)
  end
end
