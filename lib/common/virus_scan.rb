# frozen_string_literal: true

require 'clamav/commands/patch_scan_command'
require 'clamav/patch_client'

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)

      mock_enabled? || ClamAV::PatchClient.new.safe?(file_path) # patch to call our class
    end

    def mock_enabled?
      Settings.clamav.mock
    end
  end
end
