# frozen_string_literal: true

require 'clamav/commands/patch_scan_command'

module Common
  module VirusScan
    module_function

    def scan(file_path)
      # `clamd` runs within service group, needs group read
      File.chmod(0o640, file_path)

      client = ClamAV::Client.new
      client.execute(ClamAV::Commands::PatchScanCommand.new(file_path))
    end
  end
end
