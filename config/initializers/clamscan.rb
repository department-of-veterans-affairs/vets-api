# frozen_string_literal: true

ClamScan.configure do |clam_config|
  clam_config.client_location = Settings.binaries.clamdscan
  clam_config.default_scan_options = { stdout: false }
end
